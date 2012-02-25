package com.sesamecom.monitoring;

/**
 * Represents descriptive statistics about a value sampled over some period.  For example, job completion time in
 * seconds, or queue size in count of queue items.
 */
public class OperationalStatistic {
    private String component;
    private String metric;
    private Unit unit;
    private double maximum;
    private double minimum;
    private double sampleCount;
    private double sum;

    /**
     * Valid units metric values may be in.
     */
    public enum Unit {
        Seconds("Seconds"),
        Bits("Bits"),
        Bytes("Bytes"),
        Percent("Percent"),
        Count("Count"),
        BytesPerSecond("Bytes/Second"),
        BitsPerSecond("Bits/Second"),
        CountPerSecond("Count/Second");

        private String value;

        Unit(String s) {
            this.value = s;
        }

        public String getValue() {
            return value;
        }
    }

    public OperationalStatistic(String component, String metric, Unit unit, double maximum, double minimum, double sampleCount, double sum) {
        this.component = component;
        this.metric = metric;
        this.unit = unit;
        this.maximum = maximum;
        this.minimum = minimum;
        this.sampleCount = sampleCount;
        this.sum = sum;
    }

    public String getComponent() {
        return component;
    }

    public String getMetric() {
        return metric;
    }

    public Unit getUnit() {
        return unit;
    }

    public double getMaximum() {
        return maximum;
    }

    public double getMinimum() {
        return minimum;
    }

    public double getSampleCount() {
        return sampleCount;
    }

    public double getSum() {
        return sum;
    }
}
