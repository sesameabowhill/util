package com.sesamecom.util;

import javax.inject.Singleton;
import javax.naming.Context;
import javax.naming.InitialContext;
import javax.naming.NamingException;
import javax.naming.NoInitialContextException;
import javax.naming.spi.InitialContextFactory;
import javax.naming.spi.InitialContextFactoryBuilder;
import javax.naming.spi.NamingManager;
import java.util.Hashtable;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;

import static com.google.common.base.Preconditions.checkState;
import static com.google.common.collect.Iterables.limit;
import static java.util.Arrays.asList;
import static org.apache.commons.lang.StringUtils.join;
import static org.apache.commons.lang.StringUtils.split;

/**
 * An simple JNDI SPI implementation for passing JDBC DataSources around.  Allows you to bind and lookup
 * java:comp/env/jdbc/[foo] locations, which are stored in a simple Map.  Just call start() first to register with
 * NamingManager.  Will alternatively just proxy to an existing InitialContext if one is available, so it's safe to use
 * both in and outside of a container like Tomcat.  In proxy mode you can call bind without all of the ridiculous
 * createSubcontext calls.
 */
@Singleton
public class JndiContext extends InitialContext implements InitialContextFactoryBuilder, InitialContextFactory {
    protected static ConcurrentHashMap<String, Object> map = new ConcurrentHashMap<String, Object>();
    private static boolean started = false;
    private boolean proxyMode = false;

    private String pathRoot;

    public JndiContext() throws NamingException {
    }

    /**
     * Needs to be run once per JVM, and either registers us as the global InitialContextFactoryBuilder, or sets up to
     * proxy to an existing one.
     */
    public void start() {
        if (started) return;

        Context initialContext = null;
        try {
            initialContext = NamingManager.getInitialContext(null);
        } catch (NoInitialContextException e) {
        } catch (NamingException e) {
            throw new RuntimeException(e);
        }

        if (initialContext == null) {
            // nothing's registered, so register ourselves.

            try {
                NamingManager.setInitialContextFactoryBuilder(this);
            } catch (NamingException e) {
                throw new RuntimeException(e);
            }

            proxyMode = false;

        } else {
            // something else is managing the JNDI context, so we proxy.
            proxyMode = true;
        }

        started = true;
    }

    @Override
    public Object lookup(String name) throws NamingException {
        checkState(started, "No call to start() before use!");

        if (proxyMode) return new InitialContext().lookup(name);

        if ("java:comp/env".equals(name)) {
            // iBATIS likes to do an "initial context lookup" on comp/env, and then asks for jdbc/foo.  this is a simple
            // way to chain the call along.
            JndiContext withRoot = new JndiContext();
            withRoot.pathRoot = name;
            return withRoot;
        }

        String path = getPath(name);

        if (!map.containsKey(path))
            throw new NamingException(String.format("No JNDI name %s has been bound.", name));

        return map.get(path);
    }

    @Override
    public void unbind(String name) throws NamingException {
        map.remove(name);
    }

    public void unbindUnchecked(String name) {
        try {
            unbind(name);
        } catch (NamingException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public void bind(String name, Object obj) throws NamingException {
        checkState(started, "No call to start() before use!");
        String path = getPath(name);

        if (proxyMode) {
            InitialContext context = new InitialContext();
            context.createSubcontext("java:");

            // progressively build up the subcontext paths.  if you try to just bind the full path, you'll get a
            // NamingException.
            List<String> nodes = asList(split(path, "/"));
            for (int i = 1; i <= nodes.size(); i++)
                context.createSubcontext("java:" + join(limit(nodes, i).iterator(), "/"));

            context.bind(name, obj);

        } else {
            map.put(path, obj);
        }
    }

    /**
     * Just like bind, except that NamingExceptions are rethrown as RuntimeExceptions.
     */
    public void bindUnchecked(String name, Object ojb) {
        try {
            bind(name, ojb);
        } catch (NamingException e) {
            throw new RuntimeException(e);
        }
    }

    private String getPath(String name) throws NamingException {
        name = name.trim();

        if (pathRoot != null)
            // we're chaining an "initial lookup"
            name = pathRoot + "/" + name;

        if (!name.startsWith("java:comp/env"))
            // when we're the context, it's only because we're needed for JDBC DataSources, so anything else shouldn't
            // be allowed.  don't match on the full path to "jdbc" subcontext because we may be chaining.
            throw new NamingException("Only 'java:comp/env' names are supported by this SPI, got: " + name);

        return name.replace("java:", "");
    }

    // these two are only ever called if proxyMode is false

    @Override
    public Context getInitialContext(Hashtable<?, ?> environment) throws NamingException {
        return this;
    }

    @Override
    public InitialContextFactory createInitialContextFactory(Hashtable<?, ?> environment) throws NamingException {
        return this;
    }
}
