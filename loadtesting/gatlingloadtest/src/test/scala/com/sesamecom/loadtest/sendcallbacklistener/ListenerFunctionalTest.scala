package com.sesamecom.loadtest.sendcallbacklistener

import io.gatling.core.Predef._
import io.gatling.http.Predef._

/**
 * Low volume test to simply verify the system returns the expected status code.
 */
class ListenerFunctionalTest extends Simulation {

  val targetHostBaseUrl = System.getProperty("targetBaseUrl")
  val httpProtocol = http.baseURL(targetHostBaseUrl)

  val message =
    "{" +
        "\"body\": \"Gatling Load Test\"," +
        "\"bodySize\": 17," +
        "\"dateCreated\": \"2016-03-14T15:17:09.815-07:00\"," +
        "\"deleted\": false," +
        "\"deviceId\": 226665609," +
        "\"finalDestination\": \"4445556666\"," +
        "\"finalSource\": \"5554443333\"," +
        "\"fingerprint\": \"44455566665554443333\"," +
        "\"hasAttachment\": false," +
        "\"id\": 20160314151709815," +
        "\"messageTransport\": 5," +
        "\"messageType\": \"MO\"," +
        "\"read\": false," +
        "\"statusCode\": 4," +
        "\"visible\": true" +
    "}"


  val scn = scenario("JettyAsyncLoadTest")
     .exec(
       http("ok_request")
         .post("/zipwhip/receive?member=depic")
         .body(StringBody(message)))
     .exec(
       http("zipwhip_bad_url")
         .post("/zipwhip/bad-request")
         .check(status.is(400)))
     .exec(
       http("bad_vendor_url")
         .post("/bogus/receive?member=johnsmith")
         .body(StringBody(message))
         .check(status.is(404)))
     .exec(
       http("bad_correct_path_no_parameters")
         .post("/zipwhip/receive")
         .check(status.is(400)))

   setUp(scn.inject(atOnceUsers(1)).protocols(httpProtocol))
 }
