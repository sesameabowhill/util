import boto3
from boto3.dynamodb.conditions import Attr
import sys

#For dynamoDB local testing
ENDPOINT='http://localhost:8000'

AWS_ACCESS_KEY = 'bogus'
AWS_SECRET = 'bogus'


PREFIXES = ['prd-cluster-2','prd-cluster-3']  
# PREFIXES = ['jmleziva']

#samurai extracted tables, excludes statsAppointment, websites
TABLES = ['statsHealthgrades', 'statsPayPerClick', 'statsSeo', 'statsSocial']

def getClient() : 
    """
    Helper method to create a client. 
    """
    return boto3.client('dynamodb',aws_access_key_id=AWS_ACCESS_KEY, aws_secret_access_key=AWS_SECRET) #, endpoint_url='http://localhost:8000')

#Only good if a single month is desired, otherwise is very costly
# def monthCount(strTableName, strLocalDate):
#     client = getClient()
#     paginator = client.get_paginator('scan')
#     response_iterator = paginator.paginate(
#         TableName=strTableName, 
#         Select='COUNT', 
#         FilterExpression='localDate = :localDate', 
#         ExpressionAttributeValues={':localDate':{'S':strLocalDate}},
#         PaginationConfig={'PageSize': 50})
#     count = 0
#     scanned = 0
#     print "starting " + strTableName + " for " + strLocalDate
#     for page in response_iterator : 
#         count += page['Count']
#         scanned += page['ScannedCount']
#         #progress print
#         print  '.',
#         sys.stdout.write('')
#     print
#     print strTableName + " finished for " + strLocalDate + ". Scanned: " + `scanned` + " Count: " + `count`
#     return count


# Result
# {
#     'jmleziva-statsHealthgrades':{
#         '2015-05-01':40,
#         '2015-06-01':43
#     },
#     'jmleziva-statsPayPerClick':{...}, 
#     ...   
# }
def mapOfMonthlyCountByTable(strPrefix):
    #build empty dictionary of dictionarys keyed on table name
    result={}
    for table in TABLES:
        result[strPrefix + '-' + table] = {} 
    #query for monthly counts per table
    for tableName in result.keys() :
        result[tableName] = dumpMonthlyCounts(tableName)
    return result


def dumpMonthlyCounts(strTableName):
    client = getClient()
    paginator = client.get_paginator('scan')
    response_iterator = paginator.paginate(
        TableName=strTableName, 
        PaginationConfig={'PageSize': 50}) # ProjectionExpression = 'localdate', <= limiting results does not seem to work
    results = {}
    scanned = 0
    print "Scanning " + strTableName
    for page in response_iterator :
        for item in page['Items'] :
            #dict may not have current key 
            key = item['localDate']['S']
            if not(results.has_key(key)) :
                results[key] = 0
            #add count per local date
            results[key] = results[key] + 1   
        #progress print one dot per page
        scanned += page['ScannedCount']
        print  '.',
        sys.stdout.write('')
    print
    print strTableName + " finished. Scanned: " + `scanned`
    return results


# Print table data
for prefix in PREFIXES :
    x = mapOfMonthlyCountByTable(prefix)
    print

    for tableName in x.keys() :
        print "Table: " + tableName
        localDateList = [ld for ld in x[tableName]]
        localDateList.sort()
        for localDate in localDateList :
            print "    " + localDate + ": " + `x[tableName][localDate]`
    print
    print
    print 
    print
