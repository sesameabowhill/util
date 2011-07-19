/* Copyright (c) 2007, 2008, 2009 Timothy Wall, All Rights Reserved
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * <p/>
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.  
 */
package com.sesamecom.jcityhash;

import java.io.*;
import java.net.URI;
import java.net.URISyntaxException;
import java.net.URL;

public final class Native {
    private static String getNativeLibraryResourcePath(int osType, String arch, String name) {
        String osPrefix;
        arch = arch.toLowerCase();
        switch (osType) {
            case Platform.WINDOWS:
                if ("i386".equals(arch))
                    arch = "x86";
                osPrefix = "win32-" + arch;
                break;
            case Platform.MAC:
                osPrefix = "darwin";
                break;
            case Platform.LINUX:
                if ("x86".equals(arch)) {
                    arch = "i386";
                } else if ("x86_64".equals(arch)) {
                    arch = "amd64";
                }
                osPrefix = "linux-" + arch;
                break;
            case Platform.SOLARIS:
                osPrefix = "sunos-" + arch;
                break;
            default:
                osPrefix = name.toLowerCase();
                if ("x86".equals(arch)) {
                    arch = "i386";
                }
                if ("x86_64".equals(arch)) {
                    arch = "amd64";
                }
                if ("powerpc".equals(arch)) {
                    arch = "ppc";
                }
                int space = osPrefix.indexOf(" ");
                if (space != -1) {
                    osPrefix = osPrefix.substring(0, space);
                }
                osPrefix += "-" + arch;
                break;
        }
        return "/com/sesamecom/jcityhash/" + osPrefix;
    }

    public static void loadNativeLibraryFromResourcePath() {
        String libname = System.mapLibraryName("jcityhash-1.0.2");

        String arch = System.getProperty("os.arch");
        String name = System.getProperty("os.name");

        String resourceName = getNativeLibraryResourcePath(Platform.getOSType(), arch, name) + "/" + libname;

        URL url = Native.class.getResource(resourceName);

        // Add an ugly hack for OpenJDK (soylatte) - JNI libs use the usual
        // .dylib extension
        if (url == null && Platform.isMac() && resourceName.endsWith(".dylib")) {
            resourceName = resourceName.substring(0, resourceName.lastIndexOf(".dylib")) + ".jnilib";
            url = Native.class.getResource(resourceName);
        }

        if (url == null) {
            throw new UnsatisfiedLinkError("jcityhash-1.0.2 (" + resourceName + ") not found in resource path");
        }

        File lib = null;
        if (url.getProtocol().toLowerCase().equals("file")) {
            try {
                lib = new File(new URI(url.toString()));
            } catch (URISyntaxException e) {
                lib = new File(url.getPath());
            }
            if (!lib.exists()) {
                throw new Error("File URL " + url + " could not be properly decoded");
            }
        } else {
            InputStream is = Native.class.getResourceAsStream(resourceName);
            if (is == null) {
                throw new Error("Can't obtain jcityhash-1.0.2 InputStream");
            }

            FileOutputStream fos = null;
            try {
                // Suffix is required on windows, or library fails to load
                // Let Java pick the suffix, except on windows, to avoid
                // problems with Web Start.
                File dir = getTempDir();
                lib = new File(dir, "jcityhash-1.0.2" + (Platform.isWindows() ? ".dll" : ""));

                if (!lib.exists()) {
                    fos = new FileOutputStream(lib);
                    int count;
                    byte[] buf = new byte[1024];
                    while ((count = is.read(buf, 0, buf.length)) > 0) {
                        fos.write(buf, 0, count);
                    }
                }
            } catch (IOException e) {
                throw new Error("Failed to create temporary file for jcityhash-1.0.2 library: " + e);
            } finally {
                try {
                    is.close();
                } catch (IOException e) {
                }
                if (fos != null) {
                    try {
                        fos.close();
                    } catch (IOException e) {
                    }
                }
            }
        }

        System.load(lib.getAbsolutePath());
    }

    private static File getTempDir() {
        File tmp = new File(System.getProperty("java.io.tmpdir"));
        File jnatmp = new File(tmp, "jcityhash");
        jnatmp.mkdirs();
        return jnatmp.exists() ? jnatmp : tmp;
    }
}
