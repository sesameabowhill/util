package com.sesamecom.util;

import com.jolbox.bonecp.ConnectionHandle;
import com.jolbox.bonecp.hooks.AbstractConnectionHook;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.Connection;
import java.sql.SQLException;

/**
 * A BonceCP ConnectionHook that rolls back any active transaction when a connection is checked back into the pool.  If
 * any errors are encountered, they are simply logged, and remaining fault handling is left to BoneCP.
 */
public class RollBackOnCheckInConnectionHook extends AbstractConnectionHook {
    private static Logger log = LoggerFactory.getLogger(RollBackOnCheckInConnectionHook.class);

    @Override
    public void onCheckIn(ConnectionHandle connection) {
        try {
            // HACK: would prefer to go through BoneCP's wrapped versions of these calls, but they all check to see if
            // the connection is "logically closed" first, which it appears to be when this event occurs.  problems with
            // the connection may not resurface until the next client tries to use it.  unfortunately
            // {@link ConnectionHandle.markPossiblyBroken} is protected!  this means that any problems here will bubble
            // back up to e.g. iBATIS as a RuntimeException, as we're unable to throw our own SQLExceptions due to our
            // signature.

            Connection internalConnection = connection.getInternalConnection();
            if (!internalConnection.getAutoCommit())
                internalConnection.rollback();

        } catch (SQLException e) {
            log.warn("rollback->failed cause: SQLException while rolling back connection onCheckIn.", e);
        }
    }
}
