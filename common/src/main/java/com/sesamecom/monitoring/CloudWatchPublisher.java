package com.sesamecom.monitoring;

import com.amazonaws.auth.AWSCredentials;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.services.cloudwatch.AmazonCloudWatchAsyncClient;
import com.amazonaws.services.cloudwatch.model.Dimension;
import com.amazonaws.services.cloudwatch.model.MetricDatum;
import com.amazonaws.services.cloudwatch.model.PutMetricDataRequest;
import com.amazonaws.services.cloudwatch.model.StatisticSet;
import com.google.common.collect.ImmutableList;
import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Singleton;

import static com.sesamecom.config.EnvironmentConfig.*;

/**
 * Writes operational statistics to CloudWatch using fire-and-forget asynchronous calls.
 */
@Singleton
public class CloudWatchPublisher implements OperationalStatisticPublisher {
    private static final Logger log = LoggerFactory.getLogger(CloudWatchPublisher.class);

    private AmazonCloudWatchAsyncClient client;
    private Dimension environmentDimension;

    public CloudWatchPublisher() {
        String environmentName = getCloudWatchEnvironmentName();
        if (environmentName != null) {
            environmentDimension = new Dimension();
            environmentDimension.setName("Environment");
            environmentDimension.setValue(environmentName);

            AWSCredentials credentials = new BasicAWSCredentials(getAWSAccessKey(), getAWSSecretKey());
            client = new AmazonCloudWatchAsyncClient(credentials);
        }
        else {
            client = null;
            log.warn("operationalStatistics->disabled: Please specify a value for cloudWatchEnvironmentName!");
        }
    }

    @Override
    public void publish(OperationalStatistic statistic) {
        if (! backEndIsAvailable())
            return;

        StatisticSet statSet = new StatisticSet();
        statSet.setMaximum(statistic.getMaximum());
        statSet.setMinimum(statistic.getMinimum());
        statSet.setSampleCount(statistic.getSampleCount());
        statSet.setSum(statistic.getSum());

        MetricDatum datum = new MetricDatum();
        datum.setMetricName(statistic.getMetric());
        datum.setDimensions(ImmutableList.of(environmentDimension));
        datum.setTimestamp(DateTime.now(DateTimeZone.UTC).toDate());
        datum.setUnit(statistic.getUnit().getValue());
        datum.setStatisticValues(statSet);

        PutMetricDataRequest request = new PutMetricDataRequest();
        request.setNamespace("Sesame/" + statistic.getComponent());
        request.setMetricData(ImmutableList.of(datum));

        client.putMetricDataAsync(request); // fire and forget!  hope everything goes ok!
    }

    @Override
    public boolean backEndIsAvailable() {
        return client != null;
    }
}
