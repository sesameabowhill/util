package com.sesamecom.messaging.event;

/**
 * Refresh all facts for a member.
 */
public final class RefreshMemberFull extends MarshaledEvent implements RefreshSupervisorCommand {
    private String username;

    public RefreshMemberFull() {
    }

    public RefreshMemberFull(String username) {
        this.username = username;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    @Override
    public String toString() {
        return "RefreshMemberFull{" +
            "username='" + username + '\'' +
            '}';
    }
}
