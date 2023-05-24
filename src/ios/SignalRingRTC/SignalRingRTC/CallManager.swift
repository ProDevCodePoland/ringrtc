//
// Copyright 2019-2021 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import SignalRingRTC.RingRTC
import WebRTC
import SignalCoreKit

// Errors that the Call Manager APIs can throw.
@available(iOSApplicationExtension, unavailable)
public enum CallManagerError: Error {
    case apiFailed(description: String)
}

/// Primary events a Call UI can act upon.
@available(iOSApplicationExtension, unavailable)
public enum CallManagerEvent: Int32 {
    /// Inbound call only: The call signaling (ICE) is complete.
    case ringingLocal = 0
    /// Outbound call only: The call signaling (ICE) is complete.
    case ringingRemote
    /// The local side has accepted and connected the call.
    case connectedLocal
    /// The remote side has accepted and connected the call.
    case connectedRemote
    /// The call ended because of a local hangup.
    case endedLocalHangup
    /// The call ended because of a remote hangup.
    case endedRemoteHangup
    /// The call ended because the remote needs permission.
    case endedRemoteHangupNeedPermission
    /// The call ended because the call was accepted by a different device.
    case endedRemoteHangupAccepted
    /// The call ended because the call was declined by a different device.
    case endedRemoteHangupDeclined
    /// The call ended because the call was declared busy by a different device.
    case endedRemoteHangupBusy
    /// The call ended because of a remote busy message.
    case endedRemoteBusy
    /// The call ended because of glare, receiving an offer from same remote
    /// while calling them.
    case endedRemoteGlare
    /// The call ended because of recall, receiving an offer from same remote
    /// while still in an existing call with them.
    case endedRemoteReCall
    /// The call ended because it timed out during setup.
    case endedTimeout
    /// The call ended because of an internal error condition.
    case endedInternalFailure
    /// The call ended because a signaling message couldn't be sent.
    case endedSignalingFailure
    /// The call ended because setting up the connection failed.
    case endedConnectionFailure
    /// The call ended because there was a failure during glare handling.
    case endedGlareHandlingFailure
    /// The call ended because the application wanted to drop the call.
    case endedDropped
    /// The remote side has enabled video.
    case remoteVideoEnable
    /// The remote side has disabled video.
    case remoteVideoDisable
    /// The remote side has enabled screen sharing.
    case remoteSharingScreenEnable
    /// The remote side has disabled screen sharing.
    case remoteSharingScreenDisable
    /// The call dropped while connected and is now reconnecting.
    case reconnecting
    /// The call dropped while connected and is now reconnected.
    case reconnected
    /// The received offer is expired.
    case receivedOfferExpired
    /// Received an offer while already handling an active call.
    case receivedOfferWhileActive
    /// Received an offer while already handling an active call and glare was detected.
    case receivedOfferWithGlare
}

// In sync with WebRTC's PeerConnection.AdapterType.
// Despite how it looks, this is not an option set.
// A network adapter type can only be one of the listed values.
// And there are a few oddities to note:
// - "cellular" means we don't know if it's 2G, 3G, 4G, 5G, ...
//   If we know, it will be one of those corresponding enum values.
//   This means to know if something is cellular or not, you must
//   check all of those values.
// - "anyAddress" means we don't know the adapter type (like "unknown")
//   but it's because we bound to the default IP address (0.0.0.0)
//   so it's probably the default adapter (wifi if available, for example)
//   This is unlikely to happen in practice.
@available(iOSApplicationExtension, unavailable)
public enum NetworkAdapterType: Int32 {
  case unknown = 0
  case ethernet = 1
  case wifi = 2
  case cellular = 4
  case vpn = 8
  case loopback = 16
  case anyAddress = 32
  case cellular2G = 64
  case cellular3G = 128
  case cellular4G = 256
  case cellular5G = 512
}

/// Info about the current network route for sending audio/video/data
@available(iOSApplicationExtension, unavailable)
public struct NetworkRoute {
    public let localAdapterType: NetworkAdapterType

    public init(localAdapterType: NetworkAdapterType) {
        self.localAdapterType = localAdapterType
    }
}

/// The data mode allows the client to limit the media bandwidth used.
@available(iOSApplicationExtension, unavailable)
public enum DataMode: Int32 {
    /// Intended for low bitrate video calls. Useful to reduce
    /// bandwidth costs, especially on mobile data networks.
    case low = 0
    /// (Default) No specific constraints, but keep a relatively
    /// high bitrate to ensure good quality.
    case normal = 1
}

/// Type of hangup message.
@available(iOSApplicationExtension, unavailable)
public enum HangupType: Int32 {
    /// Normal hangup, typically remote user initiated.
    case normal = 0
    /// Call was accepted elsewhere by a different device.
    case accepted = 1
    /// Call was declined elsewhere by a different device.
    case declined = 2
    /// Call was declared busy elsewhere by a different device.
    case busy = 3
    /// Call needed permission on a different device.
    case needPermission = 4
}

@available(iOSApplicationExtension, unavailable)
public enum CallMessageUrgency: Int32 {
    case droppable = 0
    case handleImmediately
}

/// Describes why a ring was cancelled.
@available(iOSApplicationExtension, unavailable)
public enum RingCancelReason: Int32 {
    /// The user explicitly clicked "Decline".
    case declinedByUser = 0
    /// The device is busy with another call.
    case busy
}

@available(iOSApplicationExtension, unavailable)
public enum RingUpdate: Int32 {
    /// The sender is trying to ring this user.
    case requested = 0
    /// The sender tried to ring this user, but it's been too long.
    case expiredRing
    /// Call was accepted elsewhere by a different device.
    case acceptedOnAnotherDevice
    /// Call was declined elsewhere by a different device.
    case declinedOnAnotherDevice
    /// This device is currently on a different call.
    case busyLocally
    /// A different device is currently on a different call.
    case busyOnAnotherDevice
    /// The sender cancelled the ring request.
    case cancelledByRinger
}

/// Class to wrap the group call dictionary so group call objects can reference
/// it. All operations must be done on the main thread.
@available(iOSApplicationExtension, unavailable)
class GroupCallByClientId {
    private var groupCallByClientId: [UInt32: GroupCall] = [:]

    subscript(clientId: UInt32) -> GroupCall? {
        get { groupCallByClientId[clientId] }
        set { groupCallByClientId[clientId] = newValue }
    }
}

@available(iOSApplicationExtension, unavailable)
public protocol CallManagerDelegate: AnyObject {

    associatedtype CallManagerDelegateCallType: CallManagerCallReference

    /**
     * A call, either outgoing or incoming, should be started by the application.
     * Invoked on the main thread, asynchronously.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, shouldStartCall call: CallManagerDelegateCallType, callId: UInt64, isOutgoing: Bool, callMediaType: CallMediaType)

    /**
     * onEvent will be invoked in response to Call Manager library operations.
     * Invoked on the main thread, asynchronously.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, onEvent call: CallManagerDelegateCallType, event: CallManagerEvent)

    /**
     * onNetworkRouteChangedFor will be invoked when changes to the network routing (e.g. wifi/cellular) are detected.
     * Invoked on the main thread, asynchronously.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, onNetworkRouteChangedFor call: CallManagerDelegateCallType, networkRoute: NetworkRoute)

    /**
     * onAudiolevelsFor will be invoked regularly to provide audio levels.
     * Invoked *synchronously*.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, onAudioLevelsFor call: CallManagerDelegateCallType, capturedLevel: UInt16, receivedLevel: UInt16)

    /**
     * An Offer message should be sent to the given remote.
     * Invoked on the main thread, asynchronously.
     * If there is any error, the UI can reset UI state and invoke the reset() API.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, shouldSendOffer callId: UInt64, call: CallManagerDelegateCallType, destinationDeviceId: UInt32?, opaque: Data, callMediaType: CallMediaType)

    /**
     * An Answer message should be sent to the given remote.
     * Invoked on the main thread, asynchronously.
     * If there is any error, the UI can reset UI state and invoke the reset() API.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, shouldSendAnswer callId: UInt64, call: CallManagerDelegateCallType, destinationDeviceId: UInt32?, opaque: Data)

    /**
     * An Ice Candidate message should be sent to the given remote.
     * Invoked on the main thread, asynchronously.
     * If there is any error, the UI can reset UI state and invoke the reset() API.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, shouldSendIceCandidates callId: UInt64, call: CallManagerDelegateCallType, destinationDeviceId: UInt32?, candidates: [Data])

    /**
     * A Hangup message should be sent to the given remote.
     * Invoked on the main thread, asynchronously.
     * If there is any error, the UI can reset UI state and invoke the reset() API.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, shouldSendHangup callId: UInt64, call: CallManagerDelegateCallType, destinationDeviceId: UInt32?, hangupType: HangupType, deviceId: UInt32)

    /**
     * A Busy message should be sent to the given remote.
     * Invoked on the main thread, asynchronously.
     * If there is any error, the UI can reset UI state and invoke the reset() API.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, shouldSendBusy callId: UInt64, call: CallManagerDelegateCallType, destinationDeviceId: UInt32?)

    /**
     * A call message should be sent to the given remote recipient.
     * Invoked on the main thread, asynchronously.
     * If there is any error, the UI can reset UI state and invoke the reset() API.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, shouldSendCallMessage recipientUuid: UUID, message: Data, urgency: CallMessageUrgency)

    /**
     * A call message should be sent to all other members of the given group.
     * Invoked on the main thread, asynchronously.
     * If there is any error, the UI can reset UI state and invoke the reset() API.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, shouldSendCallMessageToGroup groupId: Data, message: Data, urgency: CallMessageUrgency)

    /**
     * Two call 'remote' pointers should be compared to see if they refer to the same
     * remote peer/contact.
     * Invoked *synchronously*.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, shouldCompareCalls call1: CallManagerDelegateCallType, call2: CallManagerDelegateCallType) -> Bool

    /**
     * The local video track has been enabled and can be connected to the
     * UI's display surface/view for the outgoing media.
     * Invoked on the main thread, asynchronously.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, onUpdateLocalVideoSession call: CallManagerDelegateCallType, session: AVCaptureSession?)

    /**
     * The remote peer has connected and their video track can be connected to the
     * UI's display surface/view for the incoming media.
     * Invoked on the main thread, asynchronously.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, onAddRemoteVideoTrack call: CallManagerDelegateCallType, track: RTCVideoTrack)

    /**
     * An update from `sender` has come in for the ring in `groupId` identified by `ringId`.
     *
     * `sender` will be the current user's ID if the update came from another device.
     *
     * Invoked on the main thread, asynchronously.
     */
    func callManager(_ callManager: CallManager<CallManagerDelegateCallType, Self>, didUpdateRingForGroup groupId: Data, ringId: Int64, sender: UUID, update: RingUpdate)
}

@available(iOSApplicationExtension, unavailable)
public protocol CallManagerCallReference: AnyObject { }

// Implementation of the Call Manager for iOS.
@available(iOSApplicationExtension, unavailable)
public class CallManager<CallType, CallManagerDelegateType>: CallManagerInterfaceDelegate where CallManagerDelegateType: CallManagerDelegate, CallManagerDelegateType.CallManagerDelegateCallType == CallType {

    public weak var delegate: CallManagerDelegateType?

    public var httpClient: HTTPClient
    public var sfuClient: SFUClient

    private var factory: RTCPeerConnectionFactory?

    // This dictionary is shared with each groupCall object, but the
    // permanent reference to it is here.
    private let groupCallByClientId: GroupCallByClientId

    private let peekInfoRequests: Requests<PeekInfo> = Requests()

    private var ringRtcCallManager: UnsafeMutableRawPointer!

    private var videoCaptureController: VideoCaptureController?

    public init(httpClient: HTTPClient, fieldTrials: [String: String] = [:]) {
        // Initialize the global object (mainly for logging).
        CallManagerGlobal.initialize(fieldTrials: fieldTrials)

        self.httpClient = httpClient
        self.sfuClient = SFUClient(httpClient: httpClient)

        // Initialize the WebRTC factory.
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        self.factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)

        self.groupCallByClientId = GroupCallByClientId()

        // Create an anonymous Call Manager interface. Ownership will
        // be transferred to RingRTC.
        let interface = CallManagerInterface(delegate: self)

        // Create the RingRTC Call Manager itself.
        guard let ringRtcCallManager = ringrtcCreateCallManager(interface.getWrapper(), self.httpClient.rtcClient) else {
            owsFail("unable to create ringRtcCallManager")
        }

        self.ringRtcCallManager = ringRtcCallManager

        Logger.debug("object! CallManager created... \(ObjectIdentifier(self))")
    }

    public func setSelfUuid(_ uuid: UUID) {
        AssertIsOnMainThread()
        Logger.debug("setSelfUuid")

        let uuidSlice = allocatedAppByteSliceFromData(maybe_data: uuid.data)
        defer { uuidSlice.bytes?.deallocate() }

        let retPtr = ringrtcSetSelfUuid(ringRtcCallManager, uuidSlice)
        if retPtr == nil {
            owsFailDebug("setSelfUuid had an error")
        }
    }

    deinit {
        // Close the RingRTC Call Manager.
        let retPtr = ringrtcClose(self.ringRtcCallManager)
        if retPtr == nil {
            Logger.warn("Call Manager couldn't be properly closed")
        }

        Logger.debug("object! CallManager destroyed... \(ObjectIdentifier(self))")
    }

    // MARK: - Control API

    /// Place a call to a remote peer.
    ///
    /// - Parameters:
    ///   - call: The application call context
    ///   - callMediaType: The type of call to place (audio or video)
    ///   - localDevice: The local device ID of the client (must be valid for lifetime of the call)
    public func placeCall(call: CallType, callMediaType: CallMediaType, localDevice: UInt32) throws {
        AssertIsOnMainThread()
        Logger.debug("call")

        let unmanagedCall: Unmanaged<CallType> = Unmanaged.passUnretained(call)

        let retPtr = ringrtcCall(ringRtcCallManager, unmanagedCall.toOpaque(), callMediaType.rawValue, localDevice)
        if retPtr == nil {
            throw CallManagerError.apiFailed(description: "call() function failure")
        }

        // Keep the call reference around until rust says we're done with the call.
        _ = unmanagedCall.retain()
    }

    public func accept(callId: UInt64) throws {
        AssertIsOnMainThread()
        Logger.debug("accept")

        let retPtr = ringrtcAccept(ringRtcCallManager, callId)
        if retPtr == nil {
            throw CallManagerError.apiFailed(description: "accept() function failure")
        }
    }

    public func hangup() throws {
        AssertIsOnMainThread()
        Logger.debug("hangup")

        let retPtr = ringrtcHangup(ringRtcCallManager)
        if retPtr == nil {
            throw CallManagerError.apiFailed(description: "hangup() function failure")
        }
    }

    public func cancelGroupRing(groupId: Data, ringId: Int64, reason: RingCancelReason?) throws {
        AssertIsOnMainThread()
        Logger.debug("cancelGroupRing")

        let groupId = allocatedAppByteSliceFromData(maybe_data: groupId)
        defer { groupId.bytes?.deallocate() }

        let retPtr = ringrtcCancelGroupRing(ringRtcCallManager, groupId, ringId, reason?.rawValue ?? -1)
        if retPtr == nil {
            throw CallManagerError.apiFailed(description: "cancelGroupRing() function failure")
        }
    }

    // MARK: - Flow API

    /// Proceed with a call after the shouldStartCall delegate was invoked.
    ///
    /// - Parameters:
    ///   - callId: The callId as provided by the shouldStartCall delegate
    ///   - iceServers: A list of RTC Ice Servers to be provided to WebRTC
    ///   - hideIp: A flag used to hide the IP of the user by using relay (TURN) servers only
    ///   - videoCaptureController: UI provided capturer interface
    ///   - dataMode: The desired data mode to start the session with
    ///   - audioLevelsIntervalMillis: If non-zero, the desired interval between audio level events (in milliseconds)
    public func proceed(callId: UInt64, iceServers: [RTCIceServer], hideIp: Bool, videoCaptureController: VideoCaptureController, dataMode: DataMode, audioLevelsIntervalMillis: UInt64?) throws {
        AssertIsOnMainThread()
        Logger.info("proceed(): callId: 0x\(String(callId, radix: 16)), hideIp: \(hideIp)")
        for iceServer in iceServers {
            for url in iceServer.urlStrings {
                Logger.info("  server: \(url)");
            }
        }

        // Create a shared media sources.
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = self.factory!.audioSource(with: audioConstraints)
        // Note: This must stay "audio1" to stay in sync with V4 signaling.
        let audioTrack = self.factory!.audioTrack(with: audioSource, trackId: "audio1")
        audioTrack.isEnabled = false

        let videoSource = self.factory!.videoSource()
        // Note: This must stay "video1" to stay in sync with V4 signaling.
        let videoTrack = self.factory!.videoTrack(with: videoSource, trackId: "video1")
        videoTrack.isEnabled = false

        // Define maximum output video format for 1:1 calls.
        videoSource.adaptOutputFormat(
            toWidth: 1280,
            height: 720,
            fps: 30
        )

        videoCaptureController.capturerDelegate = videoSource

        // Create a call context object to hold on to some of
        // the settings needed by the application when actually
        // creating the connection.
        let appCallContext = CallContext(iceServers: iceServers, hideIp: hideIp, audioSource: audioSource, audioTrack: audioTrack, videoSource: videoSource, videoTrack: videoTrack, videoCaptureController: videoCaptureController)

        let retPtr = ringrtcProceed(ringRtcCallManager, callId, appCallContext.getWrapper(), dataMode.rawValue, audioLevelsIntervalMillis ?? 0)
        if retPtr == nil {
            throw CallManagerError.apiFailed(description: "proceed() function failure")
        }
    }

    public func drop(callId: UInt64) {
        AssertIsOnMainThread()
        Logger.debug("drop")

        let retPtr = ringrtcDrop(ringRtcCallManager, callId)
        if retPtr == nil {
            owsFailDebug("ringrtcDrop() function failure")
        }
    }

    public func signalingMessageDidSend(callId: UInt64) throws {
        AssertIsOnMainThread()
        Logger.debug("signalingMessageDidSend")

        let retPtr = ringrtcMessageSent(ringRtcCallManager, callId)
        if retPtr == nil {
            throw CallManagerError.apiFailed(description: "ringrtcMessageSent() function failure")
        }
    }

    public func signalingMessageDidFail(callId: UInt64) {
        AssertIsOnMainThread()
        Logger.debug("signalingMessageDidFail")

        let retPtr = ringrtcMessageSendFailure(ringRtcCallManager, callId)
        if retPtr == nil {
            owsFailDebug("ringrtcMessageSendFailure() function failure")
        }
    }

    public func reset() {
        AssertIsOnMainThread()
        Logger.debug("reset")

        let retPtr = ringrtcReset(ringRtcCallManager)
        if retPtr == nil {
            owsFailDebug("ringrtcReset() function failure")
        }
    }

    public func setLocalAudioEnabled(enabled: Bool) {
        AssertIsOnMainThread()
        Logger.info("#outgoing_audio_enabled: \(enabled)")

        let retPtr = ringrtcGetActiveCallContext(ringRtcCallManager)
        guard let callContext = retPtr else {
            if enabled {
                owsFailDebug("Can't enable audio on non-existent context")
            }
            return
        }

        let appCallContext: CallContext = Unmanaged.fromOpaque(callContext).takeUnretainedValue()

        appCallContext.setAudioEnabled(enabled: enabled)
    }

    public func setLocalVideoEnabled(enabled: Bool, call: CallType) {
        AssertIsOnMainThread()
        Logger.debug("setLocalVideoEnabled(\(enabled))")

        let retPtr = ringrtcGetActiveCallContext(ringRtcCallManager)
        guard let callContext = retPtr else {
            if enabled {
                owsFailDebug("Can't enable video on non-existent context")
            }
            return
        }

        let appCallContext: CallContext = Unmanaged.fromOpaque(callContext).takeUnretainedValue()

        if appCallContext.setVideoEnabled(enabled: enabled) {
            // The setting changed, so actually update components to the new state.

            appCallContext.setCameraEnabled(enabled: enabled)

            if ringrtcSetVideoEnable(ringRtcCallManager, enabled) == nil {
                owsFailDebug("ringrtcSetVideoEnable() function failure")
                return
            }

            DispatchQueue.main.async {
                Logger.debug("setLocalVideoEnabled - main async")

                guard let delegate = self.delegate else { return }

                if enabled {
                    delegate.callManager(self, onUpdateLocalVideoSession: call, session: appCallContext.getCaptureSession())
                } else {
                    delegate.callManager(self, onUpdateLocalVideoSession: call, session: nil)
                }
            }
        }
    }

    public func updateDataMode(dataMode: DataMode) {
        AssertIsOnMainThread()
        Logger.debug("updateDataMode(\(dataMode))")

        ringrtcUpdateDataMode(ringRtcCallManager, dataMode.rawValue)
    }

    // MARK: - Signaling API
    public func receivedOffer<CallType: CallManagerCallReference>(call: CallType, sourceDevice: UInt32, callId: UInt64, opaque: Data, messageAgeSec: UInt64, callMediaType: CallMediaType, localDevice: UInt32, isLocalDevicePrimary: Bool, senderIdentityKey: Data, receiverIdentityKey: Data) throws {
        AssertIsOnMainThread()
        Logger.debug("receivedOffer")

        let opaqueSlice = allocatedAppByteSliceFromData(maybe_data: opaque)
        let senderIdentityKeySlice = allocatedAppByteSliceFromData(maybe_data: senderIdentityKey)
        let receiverIdentityKeySlice = allocatedAppByteSliceFromData(maybe_data: receiverIdentityKey)

        // Make sure to release the allocated memory when the function exists,
        // to ensure that the pointers are still valid when used in the RingRTC
        // API function.
        defer {
            if opaqueSlice.bytes != nil {
                 opaqueSlice.bytes.deallocate()
            }
            if senderIdentityKeySlice.bytes != nil {
                 senderIdentityKeySlice.bytes.deallocate()
            }
            if receiverIdentityKeySlice.bytes != nil {
                 receiverIdentityKeySlice.bytes.deallocate()
            }
        }

        let unmanagedRemote: Unmanaged<CallType> = Unmanaged.passUnretained(call)
        let retPtr = ringrtcReceivedOffer(ringRtcCallManager, callId, unmanagedRemote.toOpaque(), sourceDevice, opaqueSlice, messageAgeSec, callMediaType.rawValue, localDevice, isLocalDevicePrimary, senderIdentityKeySlice, receiverIdentityKeySlice)
        if retPtr == nil {
            throw CallManagerError.apiFailed(description: "receivedOffer() function failure")
        }

        // Keep the call reference around until rust says we're done with the call.
        _ = unmanagedRemote.retain()
    }

    public func receivedAnswer(sourceDevice: UInt32, callId: UInt64, opaque: Data, senderIdentityKey: Data, receiverIdentityKey: Data) throws {
        AssertIsOnMainThread()
        Logger.debug("receivedAnswer")

        let opaqueSlice = allocatedAppByteSliceFromData(maybe_data: opaque)
        let senderIdentityKeySlice = allocatedAppByteSliceFromData(maybe_data: senderIdentityKey)
        let receiverIdentityKeySlice = allocatedAppByteSliceFromData(maybe_data: receiverIdentityKey)

        // Make sure to release the allocated memory when the function exists,
        // to ensure that the pointers are still valid when used in the RingRTC
        // API function.
        defer {
            if opaqueSlice.bytes != nil {
                 opaqueSlice.bytes.deallocate()
            }
            if senderIdentityKeySlice.bytes != nil {
                 senderIdentityKeySlice.bytes.deallocate()
            }
            if receiverIdentityKeySlice.bytes != nil {
                 receiverIdentityKeySlice.bytes.deallocate()
            }
        }

        let retPtr = ringrtcReceivedAnswer(ringRtcCallManager, callId, sourceDevice, opaqueSlice, senderIdentityKeySlice, receiverIdentityKeySlice)
        if retPtr == nil {
            throw CallManagerError.apiFailed(description: "receivedAnswer() function failure")
        }
    }

    public func receivedIceCandidates(sourceDevice: UInt32, callId: UInt64, candidates: [Data]) throws {
        AssertIsOnMainThread()
        Logger.debug("receivedIceCandidates")

        let appIceCandidates: [AppByteSlice] = candidates.map { candidate in
            return allocatedAppByteSliceFromData(maybe_data: candidate)
        }

        // Make sure to release the allocated memory when the function exists,
        // to ensure that the pointers are still valid when used in the RingRTC
        // API function.
        defer {
            for appIceCandidate in appIceCandidates {
                if appIceCandidate.bytes != nil {
                    appIceCandidate.bytes.deallocate()
                }
            }
        }

        var appIceCandidateArray = appIceCandidates.withUnsafeBufferPointer { appIceCandidatesBytes in
            return AppIceCandidateArray(
                candidates: appIceCandidatesBytes.baseAddress,
                count: candidates.count
            )
        }

        let retPtr = ringrtcReceivedIceCandidates(ringRtcCallManager, callId, sourceDevice, &appIceCandidateArray)
        if retPtr == nil {
            throw CallManagerError.apiFailed(description: "ringrtcReceivedIceCandidates() function failure")
        }
    }

    public func receivedHangup(sourceDevice: UInt32, callId: UInt64, hangupType: HangupType, deviceId: UInt32) throws {
        AssertIsOnMainThread()
        Logger.debug("receivedHangup")

        let retPtr = ringrtcReceivedHangup(ringRtcCallManager, callId, sourceDevice, hangupType.rawValue, deviceId)
        if retPtr == nil {
            throw CallManagerError.apiFailed(description: "receivedHangup() function failure")
        }
    }

    public func receivedBusy(sourceDevice: UInt32, callId: UInt64) throws {
        AssertIsOnMainThread()
        Logger.debug("receivedBusy")

        let retPtr = ringrtcReceivedBusy(ringRtcCallManager, callId, sourceDevice)
        if retPtr == nil {
            throw CallManagerError.apiFailed(description: "receivedBusy() function failure")
        }
    }

    public func receivedCallMessage(senderUuid: UUID, senderDeviceId: UInt32, localDeviceId: UInt32, message: Data, messageAgeSec: UInt64) {
        AssertIsOnMainThread()
        Logger.debug("receivedCallMessage")

        let senderUuidSlice = allocatedAppByteSliceFromData(maybe_data: senderUuid.data)
        let messageSlice = allocatedAppByteSliceFromData(maybe_data: message)

        // Make sure to release the allocated memory when the function exists,
        // to ensure that the pointers are still valid when used in the RingRTC
        // API function.
        defer {
            if senderUuidSlice.bytes != nil {
                 senderUuidSlice.bytes.deallocate()
            }
            if messageSlice.bytes != nil {
                messageSlice.bytes.deallocate()
            }
        }

        ringrtcReceivedCallMessage(ringRtcCallManager, senderUuidSlice, senderDeviceId, localDeviceId, messageSlice, messageAgeSec)
    }

    // MARK: - Group Call

    public func createGroupCall(groupId: Data, sfuUrl: String, hkdfExtraInfo: Data, audioLevelsIntervalMillis: UInt64?, videoCaptureController: VideoCaptureController) -> GroupCall? {
        AssertIsOnMainThread()
        Logger.debug("createGroupCall")

        guard let factory = self.factory else {
            owsFailDebug("No factory found for GroupCall")
            return nil
        }

        let groupCall = GroupCall(ringRtcCallManager: ringRtcCallManager, factory: factory, groupCallByClientId: self.groupCallByClientId, groupId: groupId, sfuUrl: sfuUrl, hkdfExtraInfo: hkdfExtraInfo, audioLevelsIntervalMillis: audioLevelsIntervalMillis, videoCaptureController: videoCaptureController)
        return groupCall
    }

    // MARK: - Event Observers

    func onStartCall(remote: UnsafeRawPointer, callId: UInt64, isOutgoing: Bool, callMediaType: CallMediaType) {
        Logger.debug("onStartCall")

        DispatchQueue.main.async {
            Logger.debug("onStartCall - main.async")

            guard let delegate = self.delegate else { return }

            let callReference: CallType = Unmanaged.fromOpaque(remote).takeUnretainedValue()
            delegate.callManager(self, shouldStartCall: callReference, callId: callId, isOutgoing: isOutgoing, callMediaType: callMediaType)
        }
    }

    func onEvent(remote: UnsafeRawPointer, event: CallManagerEvent) {
        Logger.debug("onEvent")

        DispatchQueue.main.async {
            Logger.debug("onEvent - main.async")

            guard let delegate = self.delegate else { return }

            let callReference: CallType = Unmanaged.fromOpaque(remote).takeUnretainedValue()
            delegate.callManager(self, onEvent: callReference, event: event)
        }
    }

    func onNetworkRouteChangedFor(remote: UnsafeRawPointer, networkRoute: NetworkRoute) {
        Logger.debug("onNetworkRouteChanged")

        DispatchQueue.main.async {
            Logger.debug("onNetworkRouteChanged - main.async")

            guard let delegate = self.delegate else { return }

            let callReference: CallType = Unmanaged.fromOpaque(remote).takeUnretainedValue()
            delegate.callManager(self, onNetworkRouteChangedFor: callReference, networkRoute: networkRoute)
        }
    }

    func onAudioLevelsFor(remote: UnsafeRawPointer, capturedLevel: UInt16, receivedLevel: UInt16) {
        // The frequency of audio level updates is too high for the main thread, so
        // invoke the delegate function synchronously.

        guard let delegate = self.delegate else { return }

        let callReference: CallType = Unmanaged.fromOpaque(remote).takeUnretainedValue()
        delegate.callManager(self, onAudioLevelsFor: callReference, capturedLevel: capturedLevel, receivedLevel: receivedLevel)
    }

    // MARK: - Signaling Observers

    func onSendOffer(callId: UInt64, remote: UnsafeRawPointer, destinationDeviceId: UInt32?, opaque: Data, callMediaType: CallMediaType) {
        Logger.debug("onSendOffer")

        DispatchQueue.main.async {
            Logger.debug("onSendOffer - main.async")

            guard let delegate = self.delegate else { return }

            let callReference: CallType = Unmanaged.fromOpaque(remote).takeUnretainedValue()
            delegate.callManager(self, shouldSendOffer: callId, call: callReference, destinationDeviceId: destinationDeviceId, opaque: opaque, callMediaType: callMediaType)
        }
    }

    func onSendAnswer(callId: UInt64, remote: UnsafeRawPointer, destinationDeviceId: UInt32?, opaque: Data) {
        Logger.debug("onSendAnswer")

        DispatchQueue.main.async {
            Logger.debug("onSendAnswer - main.async")

            guard let delegate = self.delegate else { return }

            let callReference: CallType = Unmanaged.fromOpaque(remote).takeUnretainedValue()
            delegate.callManager(self, shouldSendAnswer: callId, call: callReference, destinationDeviceId: destinationDeviceId, opaque: opaque)
        }
    }

    func onSendIceCandidates(callId: UInt64, remote: UnsafeRawPointer, destinationDeviceId: UInt32?, candidates: [Data]) {
        Logger.debug("onSendIceCandidates")

        DispatchQueue.main.async {
            Logger.debug("onSendIceCandidates - main.async")

            guard let delegate = self.delegate else { return }

            let callReference: CallType = Unmanaged.fromOpaque(remote).takeUnretainedValue()
            delegate.callManager(self, shouldSendIceCandidates: callId, call: callReference, destinationDeviceId: destinationDeviceId, candidates: candidates)
        }
    }

    func onSendHangup(callId: UInt64, remote: UnsafeRawPointer, destinationDeviceId: UInt32?, hangupType: HangupType, deviceId: UInt32) {
        Logger.debug("onSendHangup")

        DispatchQueue.main.async {
            Logger.debug("onSendHangup - main.async")

            guard let delegate = self.delegate else { return }

            let callReference: CallType = Unmanaged.fromOpaque(remote).takeUnretainedValue()
            delegate.callManager(self, shouldSendHangup: callId, call: callReference, destinationDeviceId: destinationDeviceId, hangupType: hangupType, deviceId: deviceId)
        }
    }

    func onSendBusy(callId: UInt64, remote: UnsafeRawPointer, destinationDeviceId: UInt32?) {
        Logger.debug("onSendBusy")

        DispatchQueue.main.async {
            Logger.debug("onSendBusy - main.async")

            guard let delegate = self.delegate else { return }

            let callReference: CallType = Unmanaged.fromOpaque(remote).takeUnretainedValue()
            delegate.callManager(self, shouldSendBusy: callId, call: callReference, destinationDeviceId: destinationDeviceId)
        }
    }

    func sendCallMessage(recipientUuid: UUID, message: Data, urgency: CallMessageUrgency) {
        Logger.debug("sendCallMessage")

        DispatchQueue.main.async {
            Logger.debug("sendCallMessage - main.async")

            guard let delegate = self.delegate else { return }

            delegate.callManager(self, shouldSendCallMessage: recipientUuid, message: message, urgency: urgency)
        }
    }

    func sendCallMessageToGroup(groupId: Data, message: Data, urgency: CallMessageUrgency) {
        Logger.debug("sendCallMessageToGroup")

        DispatchQueue.main.async {
            Logger.debug("sendCallMessageToGroup - main.async")

            guard let delegate = self.delegate else { return }

            delegate.callManager(self, shouldSendCallMessageToGroup: groupId, message: message, urgency: urgency)
        }
    }

    func groupCallRingUpdate(groupId: Data, ringId: Int64, sender: UUID, update: RingUpdate) {
        Logger.debug("onSendHttpRequest")

        DispatchQueue.main.async {
            Logger.debug("onSendHttpRequest - main.async")

            self.delegate?.callManager(self, didUpdateRingForGroup: groupId, ringId: ringId, sender: sender, update: update)
        }
    }

    // MARK: - Utility Observers

    func onCreateConnection(pcObserverOwned: UnsafeMutableRawPointer?, deviceId: UInt32, appCallContext: CallContext) -> (connection: Connection, pc: UnsafeMutableRawPointer?) {
        Logger.debug("onCreateConnection")

        // We create default configuration settings here as per
        // Signal Messenger policies.

        // Create the configuration.
        let configuration = RTCConfiguration()

        // Update the configuration with the provided Ice Servers.
        // @todo Validate and if none, set a backup value, don't expect
        // application to know what the backup should be.
        configuration.iceServers = appCallContext.iceServers

        // Initialize the configuration.
        configuration.bundlePolicy = .maxBundle
        configuration.rtcpMuxPolicy = .require
        configuration.tcpCandidatePolicy = .disabled
        configuration.continualGatheringPolicy = .gatherContinually

        if appCallContext.hideIp {
            configuration.iceTransportPolicy = .relay
        }

        // Create the default media constraints.
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

        Logger.debug("Create application connection object...")
        let connection = Connection(pcObserverOwned: pcObserverOwned!,
                                            factory: self.factory!,
                                      configuration: configuration,
                                        constraints: constraints)

        let pc = connection.getRawPeerConnection()
        // If pc is nil CallManager will handle it internally.

        // We always negotiate for both audio and video streams, add
        // them to the connection so WebRTC sets them up.

        // Add an Audio Sender to the connection.
        connection.createAudioSender(audioTrack: appCallContext.audioTrack)

        // Add a Video Sender to the connection.
        connection.createVideoSender(videoTrack: appCallContext.videoTrack)

        return (connection, pc)
    }

    func onConnectMedia(remote: UnsafeRawPointer, appCallContext: CallContext, stream: RTCMediaStream) {
        Logger.debug("onConnectMedia")

        guard stream.videoTracks.count > 0 else {
            owsFailDebug("Missing video stream")
            return
        }

        DispatchQueue.main.async {
            Logger.debug("onConnectMedia - main async")

            guard let delegate = self.delegate else { return }

            let callReference: CallType = Unmanaged.fromOpaque(remote).takeUnretainedValue()
            delegate.callManager(self, onAddRemoteVideoTrack: callReference, track: stream.videoTracks[0])
        }
    }

    func onCompareRemotes(remote1: UnsafeRawPointer, remote2: UnsafeRawPointer) -> Bool {
        Logger.debug("onCompareRemotes")

        // Invoke the delegate function synchronously.

        guard let delegate = self.delegate else {
            return false
        }

        let callReference1: CallType = Unmanaged.fromOpaque(remote1).takeUnretainedValue()
        let callReference2: CallType = Unmanaged.fromOpaque(remote2).takeUnretainedValue()
        return delegate.callManager(self, shouldCompareCalls: callReference1, call2: callReference2)
    }

    func onCallConcluded(remote: UnsafeRawPointer) {
        Logger.debug("onCallConcluded")

        DispatchQueue.main.async {
            Logger.debug("onCallConcluded - main.async")

            let unmanagedRemote: Unmanaged<CallType> = Unmanaged.fromOpaque(remote)

            // rust lib has signaled that it's done with the call reference
            unmanagedRemote.release()
        }
    }

    // MARK: - Group Call Observers

    func requestMembershipProof(clientId: UInt32) {
        Logger.debug("requestMembershipProof")

        DispatchQueue.main.async {
            Logger.debug("requestMembershipProof - main.async")

            guard let groupCall = self.groupCallByClientId[clientId] else {
                return
            }

            groupCall.requestMembershipProof()
        }
    }

    func requestGroupMembers(clientId: UInt32) {
        Logger.debug("requestGroupMembers")

        DispatchQueue.main.async {
            Logger.debug("requestGroupMembers - main.async")

            guard let groupCall = self.groupCallByClientId[clientId] else {
                return
            }

            groupCall.requestGroupMembers()
        }
    }

    func handleConnectionStateChanged(clientId: UInt32, connectionState: ConnectionState) {
        Logger.debug("handleConnectionStateChanged")

        DispatchQueue.main.async {
            Logger.debug("handleConnectionStateChanged - main.async")

            guard let groupCall = self.groupCallByClientId[clientId] else {
                return
            }

            groupCall.handleConnectionStateChanged(connectionState: connectionState)
        }
    }

    func handleNetworkRouteChanged(clientId: UInt32, networkRoute: NetworkRoute) {
        Logger.debug("handleNetworkRouteChanged")

        DispatchQueue.main.async {
            Logger.debug("handleNetworkRouteChanged - main.async")

            guard let groupCall = self.groupCallByClientId[clientId] else {
                return
            }

            groupCall.handleNetworkRouteChanged(networkRoute: networkRoute)
        }
    }

    func handleAudioLevels(clientId: UInt32, capturedLevel: UInt16, receivedLevels: [ReceivedAudioLevel]) {
        DispatchQueue.main.async {
           guard let groupCall = self.groupCallByClientId[clientId] else {
               return
           }
        
           groupCall.handleAudioLevels(capturedLevel: capturedLevel, receivedLevels: receivedLevels)
        }
    }

    func handleJoinStateChanged(clientId: UInt32, joinState: JoinState) {
        Logger.debug("handleJoinStateChanged")

        DispatchQueue.main.async {
            Logger.debug("handleJoinStateChanged - main.async")

            guard let groupCall = self.groupCallByClientId[clientId] else {
                return
            }

            groupCall.handleJoinStateChanged(joinState: joinState)
        }
    }

    func handleRemoteDevicesChanged(clientId: UInt32, remoteDeviceStates: [RemoteDeviceState]) {
        Logger.debug("handleRemoteDevicesChanged")

        DispatchQueue.main.async {
            Logger.debug("handleRemoteDevicesChanged - main.async")

            guard let groupCall = self.groupCallByClientId[clientId] else {
                return
            }

            groupCall.handleRemoteDevicesChanged(remoteDeviceStates: remoteDeviceStates)
        }
    }

    func handleIncomingVideoTrack(clientId: UInt32, remoteDemuxId: UInt32, nativeVideoTrackBorrowedRc: UnsafeMutableRawPointer?) {
        Logger.debug("handleIncomingVideoTrack")

        guard let factory = self.factory else {
            owsFailDebug("factory was unexpectedly nil")
            return
        }

        guard let nativeVideoTrackBorrowedRc = nativeVideoTrackBorrowedRc else {
            owsFailDebug("videoTrack was unexpectedly nil")
            return
        }

        // This takes a borrowed RC.
        let videoTrack = factory.videoTrack(fromNativeTrack: nativeVideoTrackBorrowedRc)

        DispatchQueue.main.async {
            Logger.debug("handleIncomingVideoTrack - main.async")

            guard let groupCall = self.groupCallByClientId[clientId] else {
                return
            }

            groupCall.handleIncomingVideoTrack(remoteDemuxId: remoteDemuxId, videoTrack: videoTrack)
        }
    }

    func handlePeekChanged(clientId: UInt32, peekInfo: PeekInfo) {
        Logger.debug("handlePeekChanged")

        DispatchQueue.main.async {
            Logger.debug("handlePeekChanged - main.async")

            guard let groupCall = self.groupCallByClientId[clientId] else {
                return
            }

            groupCall.handlePeekChanged(peekInfo: peekInfo)
        }
    }

    func handleEnded(clientId: UInt32, reason: GroupCallEndReason) {
        Logger.debug("handleEnded")

        DispatchQueue.main.async {
            Logger.debug("handleEnded - main.async")

            guard let groupCall = self.groupCallByClientId[clientId] else {
                return
            }

            groupCall.handleEnded(reason: reason)
        }
    }
}

@available(iOSApplicationExtension, unavailable)
func allocatedAppByteSliceFromArray(maybe_bytes: [UInt8]?) -> AppByteSlice {
    guard let bytes = maybe_bytes else {
        return AppByteSlice(bytes: nil, len: 0)
    }
    let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes.count)
    ptr.initialize(from: bytes, count: bytes.count)
    return AppByteSlice(bytes: ptr, len: bytes.count)
}

@available(iOSApplicationExtension, unavailable)
func allocatedAppByteSliceFromString(maybe_string: String?) -> AppByteSlice {
    guard let string = maybe_string else {
        return allocatedAppByteSliceFromArray(maybe_bytes: nil)
    }
    return allocatedAppByteSliceFromArray(maybe_bytes: Array(string.utf8))
}

@available(iOSApplicationExtension, unavailable)
func allocatedAppByteSliceFromData(maybe_data: Data?) -> AppByteSlice {
    guard let data = maybe_data else {
        return allocatedAppByteSliceFromArray(maybe_bytes: nil)
    }
    return allocatedAppByteSliceFromArray(maybe_bytes: Array(data))
}
