package com.sesamecom.util.functions;

import com.google.common.base.Function;

import javax.annotation.Nullable;

/**
 * Simple function that returns an object's class.
 */
public class GetClass implements Function<Object, Class> {
    @Override
    public Class apply(@Nullable Object input) {
        return input.getClass();
    }

    public static GetClass getClassOf() {
        return new GetClass();
    }
}
