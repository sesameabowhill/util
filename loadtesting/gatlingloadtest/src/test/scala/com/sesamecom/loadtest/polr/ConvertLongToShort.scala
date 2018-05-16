package com.sesamecom.loadtest.polr

import io.gatling.core.Predef._
import io.gatling.http.Predef._
// https://groups.google.com/d/msg/gatling/Kts2srUj1O0/5q8aPKNLorgJ
import java.util.concurrent.atomic.AtomicInteger
import scala.concurrent.duration._
import scala.util.Random

/**
  * Smoke screen test of stats service urls
  */
class ExperimentalTest extends Simulation {

  // https://stackoverflow.com/a/1269279
  implicit def toInt(in:Integer) = in.intValue()

  val POLR_BASE_PROPERTY = "polrBaseUrl"
  val POLR_ACCESS_TOKEN = "polrAccessToken"

  val offset = new AtomicInteger()

  // Setup Scenario target
  val targetHostBaseUrl = System.getProperty(POLR_BASE_PROPERTY)

  // Fetch access token
  val polrAccessToken = System.getProperty(POLR_ACCESS_TOKEN)

  // build our own feeder to generate urls
  val feeder = 
    Iterator.continually(
      Map(
        "urx" -> (
          "https://sesamecom.com/" + Random.alphanumeric.take(20).mkString
          )
        ) 
      )

  // set base url without browser caching
  val httpConf = http.baseURL(targetHostBaseUrl).disableCaching

  // create a scenario where we ask to shorten a random url
  val myscenario = 
    scenario("ExperimentalTest")
      .feed(feeder)
      .pause(1)
      .exec { session =>
        println(session)
        println( 
          s"""/api/v2/action/shorten?key=$polrAccessToken
          |&url=${session("urx").as[String]}"""
        .stripMargin.replaceAll("\n", " ")
        )
        session
        }
      .pause(1)
      .exec( http("ShortenUrl")
        .get( session =>
        // https://alvinalexander.com/scala/how-to-create-multiline-strings-heredoc-in-scala-cookbook
        s"""/api/v2/action/shorten?key=$polrAccessToken
        |&url=${session("urx").as[String]}"""
        .stripMargin.replaceAll("\n", " ")
        )
      )
     
  // run scenario against target
  setUp(
    myscenario.inject(
      nothingFor(4 seconds),
      atOnceUsers(1),
      //rampUsers(60) over (60 seconds),
      constantUsersPerSec(15) during (240 seconds),
      )
    .protocols(httpConf)
  )

}