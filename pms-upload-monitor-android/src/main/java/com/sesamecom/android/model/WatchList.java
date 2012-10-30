package com.sesamecom.android.model;

import java.util.*;

/**
 * Created by Ivan
 */
public class WatchList {
    private Map<String, State> state;
    private List<UploadEventListener> listeners;

    public WatchList() {
        this.state = new HashMap<String, State>();
        this.listeners = new LinkedList<UploadEventListener>();
    }

    public void addListener(UploadEventListener listener) {
        listeners.add(listener);
    }

    public void startWatchingClient(String username) {
        if (!state.containsKey(username)) {
            state.put(username, State.NotListed);
        }
    }

    public void stopWatchingClient(String username) {
        state.remove(username);
    }

    public void queueUpdated(Iterable<String> inQueueClients, Iterable<String> inProgressClients) {
        Set<String> allClients = new HashSet<String>();
        checkIfClientMovedToList(inProgressClients, allClients, State.InProcess);
        checkIfClientMovedToList(inQueueClients, allClients, State.InQueue);
        for (String username : state.keySet()) {
            if (! allClients.contains(username)) {
                if (! State.NotListed.equals(state.get(username))) {
                    stateChanged(username, state.get(username), State.NotListed);
                    state.put(username, State.NotListed);
                }
            }
        }
    }

    private void checkIfClientMovedToList(Iterable<String> currentClients, Set<String> allClients, State stateInTheList) {
        for (String username : currentClients) {
            if (state.containsKey(username) && ! allClients.contains(username)) {
                if (! stateInTheList.equals(state.get(username))) {
                    stateChanged(username, state.get(username), stateInTheList);
                    state.put(username, stateInTheList);
                }
                allClients.add(username);
            }
        }
    }

    private void stateChanged(String username, State from, State to) {
        if (State.InProcess.equals(to)) {
            for (UploadEventListener listener : listeners) {
                listener.processStarted(username);
            }
        }
        if (State.NotListed.equals(to)) {
            for (UploadEventListener listener : listeners) {
                listener.processComplete(username);
            }
        }
    }

    private enum State {
        InQueue, InProcess, NotListed
    }
}
