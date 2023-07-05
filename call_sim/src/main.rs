//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

mod audio;
mod common;
mod docker;
mod report;
mod test;

use anyhow::Result;
use clap::Parser;
use std::env;
use std::time::Duration;

use crate::common::{
    AudioAnalysisMode, AudioConfig, CallConfig, ChartDimension, GroupConfig, NetworkConfig,
    NetworkConfigWithOffset, NetworkProfile, TestCaseConfig, VideoConfig,
};
use crate::docker::{build_images, clean_network, clean_up};
use crate::test::Test;

fn compile_time_root_directory() -> &'static std::ffi::OsStr {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent() // ringrtc
        .unwrap()
        .as_os_str()
}

#[derive(Parser, Debug)]
struct Args {
    /// Specifies which tests to run.
    test_sets: Vec<String>,

    /// Specifies path to the root of the ringrtc directory.
    /// Usually relative when provided on the command line.
    #[arg(long, default_value = compile_time_root_directory())]
    root: String,

    /// If set, specifies the output directory for artifacts, relative to the root. Otherwise
    /// a `call_sim/test_results` directory will be created on the provided root.
    #[arg(long, default_value = "call_sim/test_results")]
    output_dir: String,

    /// If set, specifies the directory where reference media can be found, relative to the
    /// root directory. Otherwise the `call_sim/media` directory will be assumed.
    #[arg(long, default_value = "call_sim/media")]
    media_dir: String,

    /// Builds all dependent docker images.
    #[arg(short, long)]
    build: bool,

    /// Cleans up containers and networks before running (in case prior runs failed to do so).
    #[arg(short, long)]
    clean: bool,
}

// This is an example test set. It is both a useful reference and a standard set of
// tests we can run by default. Normally, one would modify this file and run the specific
// test sets that are of interest.
async fn run_example(test: &mut Test) -> Result<()> {
    // Optional: Pre-process sounds that you will use. This will generate a spectrogram
    // and calculate a reference MOS for each sound. Normally, this might be useful,
    // but sometimes you just want to run a test and don't need this information.
    // Here we are leaving out the `silence` sound since there is no point to get a
    // MOS value for it.
    test.preprocess_sounds(vec!["normal_phrasing"]).await?;

    // Now run a test with a `default` config. Here, we will use 30-second calls and specify
    // a default call configuration. The test will actually run one or more test cases,
    // each a permutation of the call configuration, sound pairs, and network profiles.
    // In these cases, client_b is always sending recorded silence (the default).
    test.run(
        GroupConfig {
            group_name: "example".to_string(),
            chart_dimensions: vec![ChartDimension::Mos],
            x_labels: &[],
        },
        vec![TestCaseConfig {
            test_case_name: "default".to_string(),
            client_a_config: CallConfig::default().with_audio_input_name("normal_phrasing"),
            client_b_config: CallConfig::default(),
            ..Default::default()
        }],
        // Finally, the network profiles to test against can be specified. The `None`
        // profile won't try to emulate anything, which is useful when establishing
        // baseline measurements.
        vec![NetworkProfile::None],
    )
    .await?;

    Ok(())
}

// This is a test set to test a particular sound set against various network profiles.
async fn run_baseline_over_all_profiles(test: &mut Test) -> Result<()> {
    test.run(
        GroupConfig {
            group_name: "baseline_over_all_profiles".to_string(),
            chart_dimensions: vec![ChartDimension::Mos],
            x_labels: &[],
        },
        vec![TestCaseConfig {
            test_case_name: "default".to_string(),
            client_a_config: CallConfig::default().with_audio_input_name("normal_phrasing"),
            client_b_config: CallConfig::default().with_audio_input_name("normal_phrasing"),
            ..Default::default()
        }],
        vec![
            NetworkProfile::Default,
            NetworkProfile::Moderate,
            NetworkProfile::International,
            NetworkProfile::SpikyLoss,
            NetworkProfile::LimitedBandwidth(250),
            NetworkProfile::LimitedBandwidth(100),
            NetworkProfile::LimitedBandwidth(50),
            NetworkProfile::SimpleLoss(10),
            NetworkProfile::SimpleLoss(30),
        ],
    )
    .await?;

    Ok(())
}

// Here is an example running with and without DTX across a range of loss profiles.
async fn run_dtx_tests_with_loss(test: &mut Test) -> Result<()> {
    test.run(
        GroupConfig {
            group_name: "dtx_tests_with_loss".to_string(),
            chart_dimensions: vec![ChartDimension::Mos],
            x_labels: &[],
        },
        vec![
            TestCaseConfig {
                test_case_name: "with_dtx".to_string(),
                client_a_config: CallConfig {
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                client_b_config: CallConfig {
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                ..Default::default()
            },
            TestCaseConfig {
                test_case_name: "no_dtx".to_string(),
                client_a_config: CallConfig {
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        enable_dtx: false,
                        ..Default::default()
                    },
                    ..Default::default()
                },
                client_b_config: CallConfig {
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        enable_dtx: false,
                        ..Default::default()
                    },
                    ..Default::default()
                },
                ..Default::default()
            },
        ],
        vec![
            NetworkProfile::None,
            NetworkProfile::SimpleLoss(5),
            NetworkProfile::SimpleLoss(10),
            NetworkProfile::SimpleLoss(20),
            NetworkProfile::SimpleLoss(30),
            NetworkProfile::SimpleLoss(40),
        ],
    )
    .await?;

    Ok(())
}

// Here is a test to run without a TURN server, with a TURN server, and forcing the use of a
// TURN server over UDP, and then forcing the use of a TURN server over TCP.
// Notes:
//  - The default username and password are already set by default
//  - Both clients will use the TURN server (in this test)
//  - The `turn` domain name should resolve by Docker to the container with the name `turn`
async fn run_example_with_relay(test: &mut Test) -> Result<()> {
    test.run(
        GroupConfig {
            group_name: "example_with_relay".to_string(),
            chart_dimensions: vec![ChartDimension::Mos],
            x_labels: &[],
        },
        vec![
            TestCaseConfig {
                test_case_name: "no_relay".to_string(),
                client_a_config: CallConfig {
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                client_b_config: CallConfig {
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                ..Default::default()
            },
            TestCaseConfig {
                test_case_name: "with_relay".to_string(),
                client_a_config: CallConfig {
                    relay_servers: vec![
                        "turn:turn".to_string(),
                        "turn:turn:80?transport=tcp".to_string(),
                    ],
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                client_b_config: CallConfig {
                    relay_servers: vec![
                        "stun:turn".to_string(),
                        "turn:turn".to_string(),
                        "turn:turn:80?transport=tcp".to_string(),
                    ],
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                ..Default::default()
            },
            TestCaseConfig {
                test_case_name: "force_udp_relay".to_string(),
                client_a_config: CallConfig {
                    relay_servers: vec!["turn:turn".to_string()],
                    force_relay: true,
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                client_b_config: CallConfig {
                    relay_servers: vec!["turn:turn".to_string()],
                    force_relay: true,
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                ..Default::default()
            },
            TestCaseConfig {
                test_case_name: "force_tcp_relay".to_string(),
                client_a_config: CallConfig {
                    relay_servers: vec!["turn:turn:80?transport=tcp".to_string()],
                    force_relay: true,
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                client_b_config: CallConfig {
                    relay_servers: vec!["turn:turn:80?transport=tcp".to_string()],
                    force_relay: true,
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                ..Default::default()
            },
        ],
        vec![NetworkProfile::None],
    )
    .await?;
    Ok(())
}

// Here is a test set that runs two groups of tests, each should show up in the summary report
// and be graphed separately. Note that since all the tests cases are run within the set,
// they should all be uniquely named. These tests compare various ptime values against different
// losses and bandwidths.
async fn run_ptime_analysis(test: &mut Test) -> Result<()> {
    test.preprocess_sounds(vec!["speaker_a", "speaker_b"])
        .await?;

    let test_cases = [20, 40, 60, 120].map(|packet_size_ms| TestCaseConfig {
        test_case_name: format!("ptime_{packet_size_ms}"),
        client_a_config: CallConfig {
            audio: AudioConfig {
                packet_size_ms,
                ..Default::default()
            },
            ..Default::default()
        }
        .with_audio_input_name("normal_phrasing"),
        client_b_config: CallConfig {
            audio: AudioConfig {
                packet_size_ms,
                ..Default::default()
            },
            ..Default::default()
        }
        .with_audio_input_name("normal_phrasing"),
        ..Default::default()
    });

    test.run(
        GroupConfig {
            group_name: "ptime_over_loss".to_string(),
            chart_dimensions: vec![ChartDimension::Mos],
            x_labels: &[],
        },
        test_cases.clone().into(),
        vec![
            NetworkProfile::None,
            NetworkProfile::SimpleLoss(10),
            NetworkProfile::SimpleLoss(20),
            NetworkProfile::SimpleLoss(30),
            NetworkProfile::SimpleLoss(40),
            NetworkProfile::SimpleLoss(50),
        ],
    )
    .await?;

    test.run(
        GroupConfig {
            group_name: "ptime_over_bandwidth".to_string(),
            chart_dimensions: vec![ChartDimension::Mos],
            x_labels: &[],
        },
        test_cases.into(),
        vec![
            NetworkProfile::None,
            NetworkProfile::LimitedBandwidth(250),
            NetworkProfile::LimitedBandwidth(125),
            NetworkProfile::LimitedBandwidth(100),
            NetworkProfile::LimitedBandwidth(75),
            NetworkProfile::LimitedBandwidth(50),
            NetworkProfile::LimitedBandwidth(25),
        ],
    )
    .await?;

    Ok(())
}

// A test that sends video.
async fn run_video_send_over_bandwidth(test: &mut Test) -> Result<()> {
    test.preprocess_sounds(vec!["normal_phrasing"]).await?;

    test.run(
        GroupConfig {
            group_name: "video_send_over_bandwidth".to_string(),
            chart_dimensions: vec![ChartDimension::Mos],
            x_labels: &[],
        },
        vec![TestCaseConfig {
            test_case_name: "video".to_string(),
            client_a_config: CallConfig {
                video: VideoConfig {
                    // This will expect a file named "ConferenceMotion_50fps@1280x720.mp4" in the media directory.
                    // The dimensions are important, because the converted video only contains raw frame data.
                    // (This particular video *is* 50fps, but the CLI hardcodes 30fps for both send and receive.)
                    input_name: Some("ConferenceMotion_50fps@1280x720".to_string()),
                    ..Default::default()
                },
                ..CallConfig::default()
            }
            .with_audio_input_name("normal_phrasing"),
            client_b_config: CallConfig::default().with_audio_input_name("normal_phrasing"),
            ..Default::default()
        }],
        vec![
            NetworkProfile::None,
            NetworkProfile::LimitedBandwidth(2000),
            NetworkProfile::LimitedBandwidth(1500),
            NetworkProfile::LimitedBandwidth(1250),
            NetworkProfile::LimitedBandwidth(1000),
            NetworkProfile::LimitedBandwidth(750),
            NetworkProfile::LimitedBandwidth(500),
            NetworkProfile::LimitedBandwidth(250),
            NetworkProfile::LimitedBandwidth(125),
            NetworkProfile::LimitedBandwidth(100),
            NetworkProfile::LimitedBandwidth(75),
            NetworkProfile::LimitedBandwidth(50),
        ],
    )
    .await?;

    Ok(())
}

// Bi-directional video test comparing the vp8 and vp9 video codecs.
async fn run_video_compare_vp8_vs_vp9(test: &mut Test) -> Result<()> {
    test.preprocess_sounds(vec!["normal_phrasing"]).await?;

    test.run(
        GroupConfig {
            group_name: "video_compare_vp8_vs_vp9".to_string(),
            chart_dimensions: vec![ChartDimension::Mos],
            x_labels: &[],
        },
        vec![
            TestCaseConfig {
                test_case_name: "vp8".to_string(),
                client_a_config: CallConfig {
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    video: VideoConfig {
                        input_name: Some("ConferenceMotion_50fps@1280x720".to_string()),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                client_b_config: CallConfig {
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    video: VideoConfig {
                        input_name: Some("ConferenceMotion_50fps@1280x720".to_string()),
                        ..Default::default()
                    },
                    ..Default::default()
                },
                ..Default::default()
            },
            TestCaseConfig {
                test_case_name: "vp9".to_string(),
                client_a_config: CallConfig {
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    video: VideoConfig {
                        input_name: Some("ConferenceMotion_50fps@1280x720".to_string()),
                        enable_vp9: true,
                    },
                    ..Default::default()
                },
                client_b_config: CallConfig {
                    audio: AudioConfig {
                        input_name: "normal_phrasing".to_string(),
                        ..Default::default()
                    },
                    video: VideoConfig {
                        input_name: Some("ConferenceMotion_50fps@1280x720".to_string()),
                        enable_vp9: true,
                    },
                    ..Default::default()
                },
                ..Default::default()
            },
        ],
        vec![NetworkProfile::Default],
    )
    .await?;

    Ok(())
}

// Test the scenario with changing bandwidth over one minute intervals:
// 1 minute unlimited -> 1 minute 50kbps -> 1 minute 25kbps -> 1 minute unlimited
//
// Uses a 12 second reference audio file so that the resulting 240 second session recording
// can be chopped evenly and MOS calculated for each 12-second audio segment.
async fn run_changing_bandwidth_audio_test(test: &mut Test) -> Result<()> {
    let test_cases = [20, 60, 120].map(|packet_size_ms| TestCaseConfig {
        test_case_name: format!("ptime_{packet_size_ms}"),
        length_seconds: 240,
        client_a_config: CallConfig {
            audio: AudioConfig {
                input_name: "normal_12s".to_string(),
                packet_size_ms,
                analysis_mode: AudioAnalysisMode::Chopped,
                generate_spectrogram: false,
                ..Default::default()
            },
            ..Default::default()
        },
        client_b_config: CallConfig {
            audio: AudioConfig {
                input_name: "normal_12s".to_string(),
                packet_size_ms,
                analysis_mode: AudioAnalysisMode::Chopped,
                generate_spectrogram: false,
                ..Default::default()
            },
            ..Default::default()
        },
        ..Default::default()
    });

    test.run(
        GroupConfig {
            group_name: "changing_bandwidth_audio_test".to_string(),
            chart_dimensions: vec![ChartDimension::Mos],
            x_labels: &[],
        },
        test_cases.into(),
        vec![NetworkProfile::Custom(
            "limit_default".to_string(),
            vec![
                NetworkConfigWithOffset {
                    offset: Duration::from_secs(0),
                    network_config: NetworkConfig {
                        ..Default::default()
                    },
                },
                NetworkConfigWithOffset {
                    offset: Duration::from_secs(60),
                    network_config: NetworkConfig {
                        rate: 50,
                        ..Default::default()
                    },
                },
                NetworkConfigWithOffset {
                    offset: Duration::from_secs(120),
                    network_config: NetworkConfig {
                        rate: 25,
                        ..Default::default()
                    },
                },
                NetworkConfigWithOffset {
                    offset: Duration::from_secs(180),
                    network_config: NetworkConfig {
                        ..Default::default()
                    },
                },
            ],
        )],
    )
    .await?;

    Ok(())
}

#[tokio::main]
async fn main() -> Result<()> {
    let args = Args::parse();

    println!("Starting the call simulator...");

    let mut root_path = env::current_dir()?;
    root_path.push(args.root);
    println!("  Using root path: {}", root_path.display());
    env::set_current_dir(&root_path)?;

    if args.build {
        build_images().await?;
    }

    if args.clean {
        clean_up(vec![
            "client_a",
            "client_b",
            "signaling_server",
            "turn",
            "tcpdump",
            "visqol",
        ])
        .await?;
        clean_network().await?;
    }

    let mut test_sets = args.test_sets;
    if test_sets.is_empty() {
        // For quick testing, change this to the name of your test case.
        test_sets.push("example".to_string());
    }

    for test_set_name in test_sets {
        let test = &mut Test::new(
            &root_path,
            &args.output_dir,
            &args.media_dir,
            &test_set_name,
        )?;
        match test_set_name.as_str() {
            "example" => run_example(test).await?,
            "baseline_over_all_profiles" => run_baseline_over_all_profiles(test).await?,
            "dtx_tests_with_loss" => run_dtx_tests_with_loss(test).await?,
            "example_with_relay" => run_example_with_relay(test).await?,
            "ptime_analysis" => run_ptime_analysis(test).await?,
            "video_send_over_bandwidth" => run_video_send_over_bandwidth(test).await?,
            "video_compare_vp8_vs_vp9" => run_video_compare_vp8_vs_vp9(test).await?,
            "changing_bandwidth_audio_test" => run_changing_bandwidth_audio_test(test).await?,
            _ => panic!("unknown test set \"{test_set_name}\""),
        }
        test.report().await?;
    }

    Ok(())
}