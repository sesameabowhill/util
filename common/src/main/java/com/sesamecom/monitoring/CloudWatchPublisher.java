package com.sesamecom.monitoring;

import com.amazonaws.auth.AWSCredentials;
import com.amazonaws.auth.BasicAWSCredentials;
import com.amazonaws.services.cloudwatch.AmazonCloudWatchAsyncClient;
import com.amazonaws.services.cloudwatch.model.Dimension;
import com.amazonaws.services.cloudwatch.model.MetricDatum;
import com.amazonaws.services.cloudwatch.model.PutMetricDataRequest;
import com.amazonaws.services.cloudwatch.model.StatisticSet;
import com.google.common.base.Charsets;
import com.google.common.collect.ImmutableList;
import com.google.common.io.Resources;
import com.sesamecom.config.EnvironmentConfig;
import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.inject.Singleton;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URL;
import java.net.URLConnection;

import static com.sesamecom.config.EnvironmentConfig.*;

/**
 * Writes operational statistics to CloudWatch using fire-and-forget asynchronous calls.
 */
@Singleton
public class CloudWatchPublisher implements OperationalStatisticPublisher {
    private static final Logger log = LoggerFactory.getLogger(CloudWatchPublisher.class);

    private AmazonCloudWatchAsyncClient client;
    private ImmutableList<Dimension> dimensions;

    public CloudWatchPublisher() {
        String environmentName = getCloudWatchEnvironmentName();
        if (environmentName != null) {
            ImmutableList.Builder<Dimension> dimensionBuilder = new ImmutableList.Builder<Dimension>();
            dimensionBuilder.add(new Dimension().withName("Environment").withValue(environmentName));

            String ec2InstanceId = getEC2InstanceId();
            if (ec2InstanceId != null) {
                dimensionBuilder.add(new Dimension().withName("InstanceId").withValue(ec2InstanceId));
            }
            dimensions = dimensionBuilder.build();

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

        if (statistic.getSampleCount() > 0) {
            StatisticSet statSet = new StatisticSet();
            statSet.setMaximum(statistic.getMaximum());
            statSet.setMinimum(statistic.getMinimum());
            statSet.setSampleCount(statistic.getSampleCount());
            statSet.setSum(statistic.getSum());

            MetricDatum datum = new MetricDatum();
            datum.setMetricName(statistic.getMetric());
            datum.setDimensions(dimensions);
            datum.setTimestamp(DateTime.now(DateTimeZone.UTC).toDate());
            datum.setUnit(statistic.getUnit().getValue());
            datum.setStatisticValues(statSet);

            PutMetricDataRequest request = new PutMetricDataRequest();
            request.setNamespace("Sesame/" + statistic.getComponent());
            request.setMetricData(ImmutableList.of(datum));

            client.putMetricDataAsync(request); // fire and forget!  hope everything goes ok!
        } else {
            // It's a good practice to not send zero values to AWS.
        }
    }

    @Override
    public boolean backEndIsAvailable() {
        return client != null;
    }

    /**
     * Getting EC2 instance id only if we're in production mode.
     * @return instance id string
     */
    private String getEC2InstanceId() {
        if (EnvironmentConfig.getProductionMode(false)) {
            try {
                return Resources.toString(new URL("http://169.254.169.254/latest/meta-data/instance-id"),
                        Charsets.UTF_8);
            } catch (IOException e) {
                log.error("can't get EC2 instance id", e);
            }
        } else {
            log.info("set mdProdMode=true to add EC2 instance ids into CloudWatch");
        }
        return null;
    }
}
