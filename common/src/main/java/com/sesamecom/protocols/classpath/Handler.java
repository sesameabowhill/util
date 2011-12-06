package com.sesamecom.protocols.classpath;

import com.sesamecom.protocols.CustomUrlScheme;

import java.io.IOException;
import java.net.URL;
import java.net.URLConnection;
import java.net.URLStreamHandler;

/**
 * A {@link URLStreamHandler} that handles resources on the classpath.
 *
 * Complements of: http://stackoverflow.com/questions/861500/url-to-load-resources-from-the-classpath-in-java
 *
 * WARNING: Worked in an app all the way until it was bundled in a WAR, so not sure if it's actually useful.
 *
 */
public class Handler extends URLStreamHandler {
    private static boolean installed = false;
    
    /** The classloader to find resources from. */
    private final ClassLoader classLoader;

    public Handler() {
        this.classLoader = getClass().getClassLoader();
    }

    public Handler(ClassLoader classLoader) {
        this.classLoader = classLoader;
    }

    @Override
    protected URLConnection openConnection(URL u) throws IOException {
        String path = u.getPath();

        if (path.startsWith("/"))
            path = path.replaceFirst("/", "");

        final URL resourceUrl = classLoader.getResource(path);

        if (resourceUrl == null)
            throw new IOException("Unable to find classpath resource '" + path + "'.");

        return resourceUrl.openConnection();
    }
    
    public static void install() {
        if (! installed) {
            CustomUrlScheme.add(Handler.class);
            installed = true;
        }
    }
}
