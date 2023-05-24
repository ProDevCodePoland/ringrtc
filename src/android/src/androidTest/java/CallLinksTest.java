/*
 * Copyright 2023 Signal Messenger, LLC
 * SPDX-License-Identifier: AGPL-3.0-only
 */

import org.signal.ringrtc.CallException;
import org.signal.ringrtc.CallLinkState;
import org.signal.ringrtc.CallLinkRootKey;
import org.signal.ringrtc.CallManager;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.ErrorCollector;
import org.mockito.ArgumentCaptor;

import java.util.Arrays;
import java.util.concurrent.CountDownLatch;

import static org.hamcrest.CoreMatchers.is;
import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.mockito.Mockito.*;

public class CallLinksTest extends CallTestBase {
    private static final CallLinkRootKey EXAMPLE_KEY;
    static {
        try {
            EXAMPLE_KEY = new CallLinkRootKey("bcdf-ghkm-npqr-stxz-bcdf-ghkm-npqr-stxz");
        } catch (CallException e) {
            throw new AssertionError(e);
        }
    }
    private static final long EXPIRATION_EPOCH_SECONDS = 4133980800L; // 2101-01-01
    private static final String EXAMPLE_STATE_JSON = "{\"restrictions\": \"none\",\"name\":\"\",\"revoked\":false,\"expiration\":" + EXPIRATION_EPOCH_SECONDS + "}";

    @Rule
    public ErrorCollector errors = new ErrorCollector();

    @Test
    public void testKeyAccessors() throws Exception {
        final CallLinkRootKey anotherKey = CallLinkRootKey.generate();
        assertFalse(Arrays.equals(EXAMPLE_KEY.getKeyBytes(), anotherKey.getKeyBytes()));

        assertArrayEquals(EXAMPLE_KEY.deriveRoomId(), EXAMPLE_KEY.deriveRoomId());
        assertFalse(Arrays.equals(EXAMPLE_KEY.deriveRoomId(), anotherKey.deriveRoomId()));
    }

    @Test
    public void testFormatting() throws Exception {
        assertEquals("bcdf-ghkm-npqr-stxz-bcdf-ghkm-npqr-stxz", EXAMPLE_KEY.toString());
    }

    @Test
    public void testCreateSuccess() throws Exception {
        CallManager.Observer observer = mock();
        CallManager callManager = CallManager.createCallManager(observer);

        CountDownLatch latch = new CountDownLatch(1);
        callManager.createCallLink("sfu.example", new byte[] { 1, 2, 3 }, EXAMPLE_KEY, CallLinkRootKey.generateAdminPasskey(), new byte[] { 4, 5, 6 }, result -> {
            errors.checkThat(result.getStatus(), is((short)200));
            errors.checkThat(result.isSuccess(), is(true));
            errors.checkThat(result.getValue().getExpiration().getEpochSecond(), is(EXPIRATION_EPOCH_SECONDS));
            latch.countDown();
        });

        ArgumentCaptor<Long> requestId = ArgumentCaptor.forClass(Long.class);
        verify(observer).onSendHttpRequest(requestId.capture(), startsWith("sfu.example"), eq(CallManager.HttpMethod.PUT), any(), any());

        callManager.receivedHttpResponse(requestId.getValue(), 200, EXAMPLE_STATE_JSON.getBytes("UTF-8"));
        latch.await();
    }

    @Test
    public void testCreateFailure() throws Exception {
        CallManager.Observer observer = mock();
        CallManager callManager = CallManager.createCallManager(observer);

        CountDownLatch latch = new CountDownLatch(1);
        callManager.createCallLink("sfu.example", new byte[] { 1, 2, 3 }, EXAMPLE_KEY, CallLinkRootKey.generateAdminPasskey(), new byte[] { 4, 5, 6 }, result -> {
            errors.checkThat(result.getStatus(), is((short)403));
            errors.checkThat(result.isSuccess(), is(false));
            errors.checkThat(result.getValue(), is((CallLinkState)null));
            latch.countDown();
        });

        ArgumentCaptor<Long> requestId = ArgumentCaptor.forClass(Long.class);
        verify(observer).onSendHttpRequest(requestId.capture(), startsWith("sfu.example"), eq(CallManager.HttpMethod.PUT), any(), any());

        callManager.receivedHttpResponse(requestId.getValue(), 403, new byte[] {});
        latch.await();
    }

    @Test
    public void testReadSuccess() throws Exception {
        CallManager.Observer observer = mock();
        CallManager callManager = CallManager.createCallManager(observer);

        CountDownLatch latch = new CountDownLatch(1);
        callManager.readCallLink("sfu.example", new byte[] { 1, 2, 3 }, EXAMPLE_KEY, result -> {
            errors.checkThat(result.getStatus(), is((short)200));
            errors.checkThat(result.isSuccess(), is(true));
            errors.checkThat(result.getValue().getExpiration().getEpochSecond(), is(EXPIRATION_EPOCH_SECONDS));
            latch.countDown();
        });

        ArgumentCaptor<Long> requestId = ArgumentCaptor.forClass(Long.class);
        verify(observer).onSendHttpRequest(requestId.capture(), startsWith("sfu.example"), eq(CallManager.HttpMethod.GET), any(), any());

        callManager.receivedHttpResponse(requestId.getValue(), 200, EXAMPLE_STATE_JSON.getBytes("UTF-8"));
        latch.await();
    }

    @Test
    public void testReadFailure() throws Exception {
        CallManager.Observer observer = mock();
        CallManager callManager = CallManager.createCallManager(observer);

        CountDownLatch latch = new CountDownLatch(1);
        callManager.readCallLink("sfu.example", new byte[] { 1, 2, 3 }, EXAMPLE_KEY, result -> {
            errors.checkThat(result.getStatus(), is((short)404));
            errors.checkThat(result.isSuccess(), is(false));
            errors.checkThat(result.getValue(), is((CallLinkState)null));
            latch.countDown();
        });

        ArgumentCaptor<Long> requestId = ArgumentCaptor.forClass(Long.class);
        verify(observer).onSendHttpRequest(requestId.capture(), startsWith("sfu.example"), eq(CallManager.HttpMethod.GET), any(), any());

        callManager.receivedHttpResponse(requestId.getValue(), 404, new byte[] {});
        latch.await();
    }

    @Test
    public void testUpdateNameSuccess() throws Exception {
        CallManager.Observer observer = mock();
        CallManager callManager = CallManager.createCallManager(observer);

        CountDownLatch latch = new CountDownLatch(1);
        callManager.updateCallLinkName("sfu.example", new byte[] { 1, 2, 3 }, EXAMPLE_KEY, CallLinkRootKey.generateAdminPasskey(), "Secret Hideout", result -> {
            errors.checkThat(result.isSuccess(), is(true));
            latch.countDown();
        });

        ArgumentCaptor<Long> requestId = ArgumentCaptor.forClass(Long.class);
        verify(observer).onSendHttpRequest(requestId.capture(), startsWith("sfu.example"), eq(CallManager.HttpMethod.PUT), any(), any());

        callManager.receivedHttpResponse(requestId.getValue(), 200, EXAMPLE_STATE_JSON.getBytes("UTF-8"));
        latch.await();
    }

    @Test
    public void testUpdateNameFailure() throws Exception {
        CallManager.Observer observer = mock();
        CallManager callManager = CallManager.createCallManager(observer);

        CountDownLatch latch = new CountDownLatch(1);
        callManager.updateCallLinkName("sfu.example", new byte[] { 1, 2, 3 }, EXAMPLE_KEY, CallLinkRootKey.generateAdminPasskey(), "Secret Hideout", result -> {
            errors.checkThat(result.isSuccess(), is(false));
            latch.countDown();
        });

        ArgumentCaptor<Long> requestId = ArgumentCaptor.forClass(Long.class);
        verify(observer).onSendHttpRequest(requestId.capture(), startsWith("sfu.example"), eq(CallManager.HttpMethod.PUT), any(), any());

        callManager.receivedHttpResponse(requestId.getValue(), 403, new byte[] {});
        latch.await();
    }

    @Test
    public void testUpdateNameEmptySuccess() throws Exception {
        CallManager.Observer observer = mock();
        CallManager callManager = CallManager.createCallManager(observer);

        CountDownLatch latch = new CountDownLatch(1);
        callManager.updateCallLinkName("sfu.example", new byte[] { 1, 2, 3 }, EXAMPLE_KEY, CallLinkRootKey.generateAdminPasskey(), "", result -> {
            errors.checkThat(result.isSuccess(), is(true));
            latch.countDown();
        });

        ArgumentCaptor<Long> requestId = ArgumentCaptor.forClass(Long.class);
        verify(observer).onSendHttpRequest(requestId.capture(), startsWith("sfu.example"), eq(CallManager.HttpMethod.PUT), any(), any());

        callManager.receivedHttpResponse(requestId.getValue(), 200, EXAMPLE_STATE_JSON.getBytes("UTF-8"));
        latch.await();
    }

    @Test
    public void testUpdateRestrictionsSuccess() throws Exception {
        CallManager.Observer observer = mock();
        CallManager callManager = CallManager.createCallManager(observer);

        CountDownLatch latch = new CountDownLatch(1);
        callManager.updateCallLinkRestrictions("sfu.example", new byte[] { 1, 2, 3 }, EXAMPLE_KEY, CallLinkRootKey.generateAdminPasskey(), CallLinkState.Restrictions.ADMIN_APPROVAL, result -> {
            errors.checkThat(result.isSuccess(), is(true));
            latch.countDown();
        });

        ArgumentCaptor<Long> requestId = ArgumentCaptor.forClass(Long.class);
        verify(observer).onSendHttpRequest(requestId.capture(), startsWith("sfu.example"), eq(CallManager.HttpMethod.PUT), any(), any());

        callManager.receivedHttpResponse(requestId.getValue(), 200, EXAMPLE_STATE_JSON.getBytes("UTF-8"));
        latch.await();
    }

    @Test
    public void testUpdateRevokedSuccess() throws Exception {
        CallManager.Observer observer = mock();
        CallManager callManager = CallManager.createCallManager(observer);

        CountDownLatch latch = new CountDownLatch(1);
        callManager.updateCallLinkRevoked("sfu.example", new byte[] { 1, 2, 3 }, EXAMPLE_KEY, CallLinkRootKey.generateAdminPasskey(), true, result -> {
            errors.checkThat(result.isSuccess(), is(true));
            latch.countDown();
        });

        ArgumentCaptor<Long> requestId = ArgumentCaptor.forClass(Long.class);
        verify(observer).onSendHttpRequest(requestId.capture(), startsWith("sfu.example"), eq(CallManager.HttpMethod.PUT), any(), any());

        callManager.receivedHttpResponse(requestId.getValue(), 200, EXAMPLE_STATE_JSON.getBytes("UTF-8"));
        latch.await();
    }
}