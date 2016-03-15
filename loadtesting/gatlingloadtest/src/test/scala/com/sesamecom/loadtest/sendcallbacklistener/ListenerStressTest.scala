package com.sesamecom.loadtest.sendcallbacklistener

import scala.concurrent.duration._

import io.gatling.core.Predef._
import io.gatling.http.Predef._

class ListenerStressTest extends Simulation {

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
      http("ok_request_0")
        .post("/zipwhip/receive?member=depic")
        .body(StringBody(message)))
    .exec(
      http("ok_request_1")
        .post("/zipwhip/receive?member=depic")
        .body(StringBody(message)))
    .exec(
      http("ok_request_2")
        .post("/zipwhip/receive?member=depic")
        .body(StringBody(message)))
    .exec(
      http("ok_request_3")
        .post("/zipwhip/receive?member=depic")
        .body(StringBody(message)))
    .exec(
      http("ok_request_4")
        .post("/zipwhip/receive?member=depic")
        .body(StringBody(message)))

  //setUp(scn.inject(atOnceUsers(1)).protocols(httpProtocol))
  setUp(scn.inject(rampUsers(10000) over(20 seconds)).protocols(httpProtocol))
}
