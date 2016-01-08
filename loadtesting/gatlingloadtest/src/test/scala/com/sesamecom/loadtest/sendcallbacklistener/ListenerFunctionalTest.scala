package com.sesamecom.loadtest.sendcallbacklistener

import io.gatling.core.Predef._
import io.gatling.http.Predef._

/**
 * Low volume test to simply verify the system returns the expected status code.
 */
class ListenerFunctionalTest extends Simulation {

  val targetHostBaseUrl = System.getProperty("targetBaseUrl")
  val httpProtocol = http.baseURL(targetHostBaseUrl)

  val scn = scenario("JettyAsyncLoadTest")
     .exec(
       http("ok_request")
         .post("/zipwhip/receive?member=johnsmith")
         .formParam("""{"payload":"stuff"}""", ""))
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

   setUp(scn.inject(atOnceUsers(1)).protocols(httpProtocol))
 }
