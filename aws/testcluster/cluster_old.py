import boto.ec2
import boto.ec2.elb
import boto.sns
import json
import httplib
import smtplib
import time as timer
from time import time

#
# UPDATE THIS VARIABLE WHEN MODIFYING THE SCRIPT
#
script_version = '2017-05-16'

aws_key = 'REPLACE_ME'
aws_secret = 'REPLACE_ME'

tc1_priority1 = {
    "i-b3cdd8d8" : "test-cluster-1-nas-01",
    "i-c8726bab" : "test-cluster-1-nas-02",
    "i-2cd7987f" : "test-cluster-1-nasEnctest-03",
    "i-c80ddbe3" : "test-cluster-1-nasEnctest-04",
    "i-45308425" : "test-cluster-1-jump",
    "i-35c4ae58" : "test-cluster-1-nat-01",
    "i-26a8db45" : "test-cluster-1-nat-02",
    "i-f6e65e93" : "test-cluster-1-chef",
    "i-b0fc1ad3" : "test-cluster-1-db1"
}

tc1_priority2 = {
    "i-f12f9c91" : "test-cluster-1-smtp",
    "i-984155b9" : "test-cluster-1-sendng",
    "i-7e4ff712" : "test-cluster-1-web-01",
    "i-6d889b0d" : "test-cluster-1-web-02",
    "i-0dcf3a45137df4505" : "test-cluster-1-facts",
    "i-fafd1b99" : "test-cluster-1-send",
    "i-b92f9cd9" : "test-cluster-1-sendcb-01",
    "i-8a756ce9" : "test-cluster-1-sendcb-02",
    "i-c0391e73" : "test-cluster-1-sendcb-processor-01",
    "i-3fdcd154" : "test-cluster-1-logs",
    "i-868ecb36" : "test-cluster-1-payments-01",
    "i-7afd1b19" : "test-cluster-1-pmsup",
    "i-365b3a5a" : "test-cluster-1-imageup",
    "i-4a5d3c26" : "test-cluster-1-memcache-01",
    "i-0f8e9d6f" : "test-cluster-1-memcache-02",
    "i-b70da7dd" : "test-cluster-1-charts",
    "i-cc5d3ca0" : "test-cluster-1-status",
    "i-c7cdd8ac" : "test-cluster-1-migration",
    "i-17cdd87c" : "test-cluster-1-etl",
    "i-ca680353" : "test-cluster-1-sapi2"
}

tc1_sapi_min_priority1 = {
    "i-45308425" : "test-cluster-1-jump",
    "i-35c4ae58" : "test-cluster-1-nat-01",
    "i-26a8db45" : "test-cluster-1-nat-02",
    "i-b0fc1ad3" : "test-cluster-1-db1"
}

tc1_sapi_min_priority2 = {
    "i-ca680353" : "test-cluster-1-sapi2"
}


tc2_priority1 = {
    "i-6b40f087" : "test-cluster-2-nas-01",
    "i-e583ad0f" : "test-cluster-2-nas-02",
    "i-822943e7" : "test-cluster-2-nat-01",
    "i-43ffb421" : "test-cluster-2-nat-02",
    "i-d82aedb4" : "test-cluster-2-db1",
    "i-c03de3ab" : "test-cluster-2-jump",
    "i-38d4c85b" : "test-cluster-2-chef"
}

tc2_priority2 = {
    "i-c79375aa" : "test-cluster-2-janitor",
    "i-39833f5b" : "test-cluster-2-charts",
    "i-e461e685" : "test-cluster-2-etl",
    "i-1661e677" : "test-cluster-2-facts",
    "i-af0bf9c2" : "test-cluster-2-sendcb-01",
    "i-490b2cfa" : "test-cluster-2-sendcb-processor-01",
    "i-59a99131" : "test-cluster-2-logs",
    "i-1c697975" : "test-cluster-2-web-02",
    "i-8a8fb167" : "test-cluster-2-stats-01",
    "i-223de349" : "test-cluster-2-web-01",
    "i-50b2ad3c" : "test-cluster-2-memcache-02",
    "i-7260e713" : "test-cluster-2-memcache-01",
    "i-d13f66be" : "test-cluster-2-sendcb-02",
    "i-a7b78fcf" : "test-cluster-2-send",
    "i-690bf904" : "test-cluster-2-status",
    "i-4bb68e23" : "test-cluster-2-migration",
    "i-7d9ea607" : "test-cluster-2-sendng",
    "i-1b823e79" : "test-cluster-2-smtp",
    "i-35b68e5d" : "test-cluster-2-imageup",
    "i-928acf22" : "test-cluster-2-payments-01",
    "i-5a6dea3b" : "test-cluster-2-pmsup"
}

tc1_elbs = {
    "test-clus-ElasticL-1IBE4F4X6W9XI": "i-7afd1b19",
    "test-clus-ElasticL-1U7DQ9RODD396": "i-6d889b0d,i-7e4ff712",
    "test-clus-ElasticL-RA6HTRYY9ZF3": "i-6d889b0d,i-7e4ff712",
    "test-clus-ElasticL-1E2UGD1BP2C97": "i-6d889b0d,i-7e4ff712",
    "test-clus-ElasticL-BHLKAB8EHRSZ": "i-7afd1b19",
    "test-clus-ElasticL-1MBRV1I03PHDO": "i-8a756ce9,i-b92f9cd9",
    "test-clus-ElasticL-13FZ3WKQF4EB9": "i-365b3a5a",
    "test-clus-ElasticL-imguprep": "i-365b3a5a",
    "test-clus-sapi1": "i-ca680353"
}

tc2_elbs = {
    "test-clus-ElasticL-1HBKGRLPGMNOG": "i-5a6dea3b",
    "test-clus-ElasticL-1NQYD52SKC5CG": "i-1c697975,i-223de349",
    "test-clus-ElasticL-1R0GSN9T4TYE9": "i-1c697975,i-223de349",
    "test-clus-ElasticL-1VC7NM94RRPXC": "i-5a6dea3b",
    "test-clus-ElasticL-1WXBSUU7OZYD0": "i-1c697975,i-223de349",
    "test-clus-ElasticL-1XLEAMD4UO6BY": "i-35b68e5d",
    "test-clus-ElasticL-8ZCJHCSL9KXZ": "i-35b68e5d",
    "test-clus-ElasticL-9KTXUHX6QKZY": "i-af0bf9c2,i-d13f66be"
}


tc1_sapi_min_elbs = {
    "test-clus-sapi1": "i-ca680353"
}


ec2_conn = boto.ec2.connect_to_region("us-east-1",
                        aws_access_key_id=aws_key,
                        aws_secret_access_key=aws_secret)

elb_conn = boto.ec2.elb.connect_to_region('us-east-1',
                        aws_access_key_id=aws_key,
                        aws_secret_access_key=aws_secret)

sns_conn = boto.sns.connect_to_region('us-east-1',
                        aws_access_key_id=aws_key,
                        aws_secret_access_key=aws_secret)

# arn:aws:sns:us-east-1:207752054332:test-cluster-status-TEST for testing
sns_topic = "arn:aws:sns:us-east-1:207752054332:test-cluster-status"
glip_webhook_url = "https://hooks.glip.com/webhook/8b127fc0-b7a5-4b39-b381-c4500e3aada8"

def getStatus(instance_list):
    for instanceId in instance_list:
        instance = ec2_conn.get_only_instances(instance_ids=[instanceId])
        print instance_list[instanceId] + " (" + instanceId + "} = " + instance[0].state


def resetELBs(elb_dict):

    message = "\n\n"
    elbs = elb_conn.get_all_load_balancers(load_balancer_names=elb_dict.keys())

    for elb in elbs:
        message += str(elb.get_instance_health()) + "\n\n"
        for instanceState in elb.get_instance_health():
            if instanceState.state != "InService":
                print "Instance " + instanceState.instance_id + " is out of service!\n"
                elb.deregister_instances(instanceState.instance_id)
                elb.register_instances(instanceState.instance_id)

                for instanceState in elb.get_instance_health():
                    timeout = 20
                    while instanceState != "InService" and timeout > 0:
                        print "."
                        timer.sleep(5)
                        timeout -=5
                        print timeout
                        instanceState = elb.get_instance_health()

    return message

def startInstances(instance_list):

    message = ""
    instances = ec2_conn.get_only_instances(instance_ids=instance_list.keys())
    for instance in instances :
        if (instance.state not in 'running'):
            print "Starting " + (str(instance)).partition(":")[2]
            instance.start()

    for instance in instances:
        while instance.state not in ('running'):
            print "Waiting on " + (str(instance)).partition(":")[2]
            timer.sleep(5)
            instance.update()

        instanceId = (str(instance)).partition(":")[2]
        print "\n\n" + instance_list[instanceId] + " (" + instanceId + "} = " + instance.state
        message += "\n\n" + instance_list[instanceId] + " (" + instanceId + "} = " + instance.state

    return message

def stopInstances(instance_list):

    message = ""
    instances = ec2_conn.get_only_instances(instance_ids=instance_list.keys())

    for instance, name in instance_list.items() :
        print instance + " ( " + name + " )"

    shutdown = raw_input("\n\n Confirm Shutdown > (yes to continue, else abort) ")

    if shutdown == 'yes':
        for instance in instances :
            if instance.state in ('running'):
                 instance.stop()

        for instance in instances :
            while instance.state not in ('stopping') and instance.state not in ('stopped'):
                 print "Waiting on " + (str(instance)).partition(":")[2]
                 timer.sleep(3)
                 instance.update()

            instanceId = (str(instance)).partition(":")[2]
            print "\n\n" + instance_list[instanceId] + " (" + instanceId + "} = " + instance.state
            message += "\n\n" + instance_list[instanceId] + " (" + instanceId + "} = " + instance.state
    else:
        print "User aborted"

    return message

def send_notifications(message, subject):
    send_mail(message, subject)
    send_glip_message(subject)

def send_mail(message, subject):
    message += "\n\n Script Version: " + script_version
    sns_conn.publish(topic=sns_topic, message=message, subject=subject)

def send_glip_message(message):
    headers = {"Content-type": "application/json"}
    postbody = {
        "activity":"Test Cluster Status Update [Ver: " + script_version + "]",
        "body": message
    }
    con = httplib.HTTPSConnection("hooks.glip.com")
    con.request("POST", "/webhook/8b127fc0-b7a5-4b39-b381-c4500e3aada8", json.dumps(postbody), headers)
    response = con.getresponse()
    if response.status != 200:
        responseText = response.read()
        print "\nWARNING: Posting to glip webhook failed. Http Status: " + str(response.status) + " Response text: " + responseText + "\n\n"


def start_tc1():

    print "\n\n *** Starting Priority 1 Instances in TC1 *** "
    message = "\n\n *** Starting Priority 1 Instances in TC1 *** "

    start = time()
    message += startInstances(tc1_priority1)

    print "\n\n *** Starting Priority 2 Instances in TC1 *** "
    message += "\n\n *** Starting Priority 2 Instances in TC1 *** "
    message += startInstances(tc1_priority2)

    print "\n\n *** Resetting Elastic Load Balancers for TC1 ****"
    message += "\n\n *** Resetting Elastic Load Balancers for TC1 ****"
    message += resetELBs(tc1_elbs)

    print "TC1 Started."
    message +=  "TC1 Started."

    elapsed = time() - start
    message += "\n\n Took " + str(elapsed) + " ms to start all instances and reset load balancers"

    send_notifications(message, "Test Cluster 1 Started")

def start_tc2():

    print "\n\n *** Starting Priority 1 Instances in TC2 *** "
    message = "\n\n *** Starting Priority 1 Instances in TC2 *** "

    start = time()
    message += startInstances(tc2_priority1)

    print "\n\n *** Starting Priority 2 Instances in TC2 *** "
    message += "\n\n *** Starting Priority 2 Instances in TC2 *** "
    message += startInstances(tc2_priority2)

    print "\n\n *** Resetting Elastic Load Balancers for TC2 *** "
    message += "\n\n *** Resetting Elastic Load Balancers for TC2 *** "
    message += resetELBs(tc2_elbs)

    print "TC2 Started."
    message += "TC2 Started."

    elapsed = time() - start
    message += "\n\n Took " + str(elapsed) + " ms to start all instances and reset load balancers"

    send_notifications(message, "Test Cluster 2 Started")

def start_tc1_sapi_min():

    print "\n\n *** Starting Minimal Sesame API Priority 1 Instances in TC1 *** "
    message = "\n\n *** Starting Minimal Sesame API Priority 1 Instances in TC1 *** "

    start = time()
    message += startInstances(tc1_sapi_min_priority1)

    print "\n\n *** Starting Minimal Sesame API Priority 2 Instances in TC1 *** "
    message += "\n\n *** Starting Minimal Sesame API Priority 2 Instances in TC1 *** "
    message += startInstances(tc1_sapi_min_priority2)

    print "\n\n *** Resetting Elastic Load Balancers for TC1 Minimal Sesame API ****"
    message += "\n\n *** Resetting Elastic Load Balancers for TC1 Minimal Sesame API ****"
    message += resetELBs(tc1_sapi_min_elbs)

    print "TC1 Minimal Sesame API Started."
    message +=  "TC1 Minimal Sesame API Started."

    elapsed = time() - start
    message += "\n\n Took " + str(elapsed) + " ms to start all instances and reset load balancers"

    send_notifications(message, "Test Cluster 1 Sesame API Minimal - Started")


def stop_tc1():
    message = "Stopping TC1"
    start = time()

    message += stopInstances(dict(tc1_priority1.items() + tc1_priority2.items()))

    elapsed = time() - start

    message += "\n\n Took " + str(elapsed) + " ms to initiate stop for all instances."
    send_notifications(message, "Test Cluster 1 Stopped")

def stop_tc2():
    message = "Stopping TC2"
    start = time()

    message += stopInstances(dict(tc2_priority1.items() + tc2_priority2.items()))

    elapsed = time() - start
    message += "\n\n Took " + str(elapsed) + " ms to initiate stop for all instances."

    send_notifications(message, "Test Cluster 2 Stopped")
