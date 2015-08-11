#
#  Utility script to count and copy data in S3. Was implemented for "backfilled" data from 
#  Samurai in which the stat service would extract and use to populate a DynamoDB table. This 
#  file exists to provide example code snippets.
#
#  USE AT YOUR OWN RISK 
# 

import boto3
import sys


def countObjectWithPrefix(client, strBucket, strPrefix) :
    """
    Returns an integer. Countes the number of objects in a given 
    bucket that match a given prefix. 
    """
    paginator = client.get_paginator('list_objects')
    response_iterator = paginator.paginate(
        Bucket= strBucket,
        Prefix= strPrefix,
    )
    counter = 0
    for page in response_iterator :
        if 'Contents' in page.keys() :
            for obj in page['Contents'] :
                    # print obj['Key']
                    counter = counter + 1
    return counter


def padded2DigitNumberAsStringListFromRange(intStart, intEnd) : 
    return [`x`.zfill(2) for x in range(intStart, intEnd + 1)]


def countBackfillData(client) :
    """
    Count data per path for backfilled samurai data. Keep in mind that a single member may have 
    multiple files for a given month and these stats don't provide distinct member statistcs. 
    """
    for path in ["prod","dev"] :
        for report in ["Social","SEO","HG","PPC"] :
            for month in padded2DigitNumberAsStringListFromRange(8,12) :
                prefix = path + "/reporting/data/" + report + "/2014/" + month + "/"
                print prefix + " " + `countObjectWithPrefix(client, "vpc-prd-web-samurai", prefix)`


def count2015Data(client) :
    """
    Count the data in paths for the Samurai 2015 extracted data.  
    """
    for report in ["Social","SEO","HG","PPC"] :
        for month in padded2DigitNumberAsStringListFromRange(1,7):
            prefix = "prod/reporting/data/" + report + "/2015/" + month + "/"
            print prefix + " " + `countObjectWithPrefix(client, "vpc-prd-web-samurai", prefix)`


# listOfObjectKeys(client, 'vpc-prd-web-samurai','prod/reporting/data/Social/2014/09/')
def listOfObjectKeys(client, strBucket, strPrefix) :
    """
    Return a list of object keys with the provided prefix for a given bucket 
    """
    result = []
    paginator = client.get_paginator('list_objects')
    response_iterator = paginator.paginate(
        Bucket= strBucket,
        Prefix= strPrefix,
    )
    for page in response_iterator :
        if 'Contents' in page.keys() :
            for obj in page['Contents'] :
                    result.append(obj['Key'])
    return result


def copyBackFillDataFromDevToProd(client, listStrReports, listStrMonths) :
    """
    This funcition was written for a one time use and is very specific to that context. However the example
    code may be useful for future scripts. 

    Utility to copy objects to a new key in the same vpc-prd-web-samurai bucket. This was used to "move"
    extracted data from the /dev path to the /prod path. The data is production data, but due to the way 
    Samurai populates historical data export files, they are exported to /dev instead of /prod. This function
    moves the objects.  
    """
    strBucket = "vpc-prd-web-samurai"; 
    print listStrMonths
    for report in listStrReports :
        for month in listStrMonths :            
            count = 0
            sourcePrefix = "dev/reporting/data/" + report + "/2014/" + month + "/"
            sourceKeys = listOfObjectKeys(client, strBucket, sourcePrefix)
            for key in sourceKeys :
                destinationKey = "prod" + key[3:]
                client.copy_object(CopySource=strBucket + "/" + key, Bucket=strBucket, Key=destinationKey)
                count += 1
                print  '.',
                sys.stdout.write('')
            print 
            print "Copied " + `count` + " for " + sourcePrefix





# AWS_ACCESS_KEY = 'bogus'                                                       
# AWS_SECRET = 'bogus'                                       

# #low level access
# client = boto3.client('s3',aws_access_key_id=AWS_ACCESS_KEY, aws_secret_access_key=AWS_SECRET)

# countObjectWithPrefix(client, 'vpc-prd-web-samurai','prod/reporting/data/Social/2014/08/')
# countBackfillData(client)

# # client.copy_object(Bucket="vpc-prd-web-samurai", Key="prod/reporting/data/Social/2014/07/1417645806_SC-00026835_Social", CopySource="vpc-prd-web-samurai/dev/reporting/data/Social/2014/07/1417645806_SC-00026835_Social")

# copyBackFillDataFromDevToProd(client, ["PPC"], ["08"])

# copyBackFillDataFromDevToProd(client, ["PPC"], ["08","09","10","11","12"])


# copyBackFillDataFromDevToProd(client, ["Social","SEO","HG"], ["08","09"]) 





