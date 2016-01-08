package com.sesamecom.loadtest.sendcallbacklistener

import scala.concurrent.duration._

import io.gatling.core.Predef._
import io.gatling.http.Predef._

class ListenerStressTest extends Simulation {

  val targetHostBaseUrl = System.getProperty("targetBaseUrl")
  val httpProtocol = http.baseURL(targetHostBaseUrl)

  val scn = scenario("JettyAsyncLoadTest")
    .exec(
      http("ok_request_0")
        .post("/zipwhip/receive?member=johnsmith")
        .formParam("""{"payload":"stuff"}""", ""))
    .exec(
      http("ok_request_1")
        .post("/zipwhip/receive?member=testAdaGonzales")
        .formParam("""{"name"""", """"AdaGonzales"}"""))
    .exec(
      http("ok_request_2")
        .post("/zipwhip/receive?member=testAllisonPalmer")
        .formParam("""{"name"""", """"AllisonPalmer"}"""))
    .exec(
      http("ok_request_3")
        .post("/zipwhip/receive?member=testAnaWatson")
        .formParam("""{"name"""", """"AnaWatson"}"""))
    .exec(
      http("ok_request_4")
        .post("/zipwhip/receive?member=testAndrePatrick")
        .formParam("""{"name"""", """"AndrePatrick"}"""))
    .exec(
      http("bad_no_path_after_zipwhip_vendor")
        .post("/zipwhip/")
        .check(status.is(400)))
    .exec(
      http("zipwhip_bad_url")
        .post("/zipwhip/bad-request")
        .check(status.is(400)))
    .exec(
      http("bad_vendor_url")
        .post("/bogus/receive?member=johnsmith")
        .formParam("""{"value" :"stuff"}""", "")
        .check(status.is(404)))
    .exec(
      http("bad_correct_path_no_parameters")
        .post("/zipwhip/receive")
        .check(status.is(400)))
    .exec(
      http("bad_get_instead_of_post")
        .put("/zipwhip/receive?member=johnsmith")
        .check(status.is(405)))

  //setUp(scn.inject(atOnceUsers(1)).protocols(httpProtocol))
  setUp(scn.inject(rampUsers(20000) over(20 seconds)).protocols(httpProtocol))
}
