package com.sesamecom.loadtest.polr

import io.gatling.core.Predef._
import io.gatling.http.Predef._
// https://groups.google.com/d/msg/gatling/Kts2srUj1O0/5q8aPKNLorgJ
import java.util.concurrent.atomic.AtomicInteger
import scala.concurrent.duration._
import scala.util.Random

// beware: you need to import the jdbc module
import io.gatling.jdbc.Predef._

/**
  * Smoke screen test of stats service urls
  */
class ClickThroughTest extends Simulation {

  // https://stackoverflow.com/a/1269279
  implicit def toInt(in:Integer) = in.intValue()

  val POLR_BASE_PROPERTY = "polrBaseUrl"
  val POLR_ACCESS_TOKEN = "polrAccessToken"

  // Setup Scenario target
  val targetHostBaseUrl = System.getProperty(POLR_BASE_PROPERTY)

  // Fetch access token
  val polrAccessToken = System.getProperty(POLR_ACCESS_TOKEN)

  val feeder = jdbcFeeder("jdbc:mysql://localhost:3308/polr", "root", "sesame", "SELECT short_url FROM links").random

  // set base url without browser caching: .disableCaching
  val httpConf = http.baseURL(targetHostBaseUrl).disableFollowRedirect

  // create a scenario where we ask to shorten a random url
  val myscenario = 
    scenario("ClickThroughTest")
      .feed(feeder)
      .exec { session =>
//        println(session)
        println (
          s"""/api/v2/action/lookup?key=$polrAccessToken
          |&url_ending=${session("short_url").as[String]}"""
          .stripMargin.replaceAll("\n", " ")
          )
        session
        }
      .pause(1)
      .exec( http("lookupURL")
        .get( session =>
        // https://alvinalexander.com/scala/how-to-create-multiline-strings-heredoc-in-scala-cookbook
        s"""/api/v2/action/lookup?key=$polrAccessToken
        |&url_ending=${session("short_url").as[String]}"""
        .stripMargin.replaceAll("\n", " ")
        )
      )
     
  // run scenario against target
  setUp(
    myscenario.inject(
      nothingFor(4 seconds),
      atOnceUsers(1),
      constantUsersPerSec(20) during (240 seconds),
      )
    .protocols(httpConf)
  )

}

// mvn gatling:test -Dgatling.simulationClass=com.sesamecom.loadtest.polr.ClickThroughTest -DpolrBaseUrl=http://127.0.0.1:8080 -DpolrAccessToken=e3cea37097877464d4cb7f65cce215
