package com.sesamecom.loadtest.polr

import io.gatling.core.Predef._
import io.gatling.http.Predef._
import java.util.concurrent.atomic.AtomicInteger

/**
  * Smoke screen test of stats service urls
  */
class PolrTest extends Simulation {

  val POLR_BASE_PROPERTY = "polrBaseUrl"
  val POLR_ACCESS_TOKEN = "polrAccessToken"

  val offset = new AtomicInteger()

  // Setup Scenario target
  val targetHostBaseUrl = System.getProperty(POLR_BASE_PROPERTY)
  val httpProtocol = http.baseURL(targetHostBaseUrl)

  // Fetch access token
  val polrAccessToken = System.getProperty(POLR_ACCESS_TOKEN)


  // Shorten link
  //  curl -i 'http://127.0.0.1:8555/api/v2/action/shorten?key=a4cd7be3c3fa9ffbccb67053d44ff9&url=http://www.oracle.com/technetwork/java/javase/10-relnotes-4108314.html&response_type=json'
  //  HTTP/1.1 200 OK
  //  Server: nginx/1.8.0
  //  Content-Type: application/json
  //  Transfer-Encoding: chunked
  //  Connection: keep-alive
  //  X-Powered-By: PHP/7.2.4
  //  Cache-Control: no-cache
  //  Date: Fri, 20 Apr 2018 19:26:16 GMT
  //  Access-Control-Allow-Origin: *
  //  Set-Cookie: laravel_session=eyJpdiI6Im16SWl4YzJ2bjlTRE13MllLbXNncEE9PSIsInZhbHVlIjoiOThPaEVONGN0S0dvNkUrZGlvaFdpeEorM2M5NEdEZUtzNk9kemtZR2N0c2ZyV25ZTFFGb0piVE9yZzlScDE0Y3VBSFJTUHNKbHV5UmE2b3dJc1F6VEE9PSIsIm1hYyI6ImJkY2E5YWZmNWY3MDc2NGQzYzk2ODRiN2RlZWYwZWRlNTRlZGI2ZmM5ZGI0NTgzMzAzOGUzNzAzM2E5OTM4YjIifQ%3D%3D; expires=Fri, 20-Apr-2018 21:26:16 GMT; Max-Age=7200; path=/; HttpOnly
  //
  //  {"action":"shorten","result":"http:\/\/10.70.0.132:8555\/cu0ZZ"}
  val scn = scenario("PolrTest")
    .exec(
      http("ShortenUrl")
        .get(s"/api/v2/action/shorten?key=$polrAccessToken&url=${createTargetUrl(offset.getAndIncrement)}"))


  // run scenario against target
  setUp(scn.inject(atOnceUsers(5)).protocols(httpProtocol))


  /**
    * @return an incremented URL. Currently goes against scala principles as it utilizes share stated.
    */
  def createTargetUrl(increment: Int) = s"https://sesamecom.com/${increment}"
}
