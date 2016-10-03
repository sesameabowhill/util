package com.sesamecom.loadtest.statservice

import io.gatling.core.Predef._
import io.gatling.http.Predef._

/**
  * Smoke screen test of stats service urls
  */
class StatsFunctionalTest extends Simulation {

  val targetHostBaseUrl = System.getProperty("statsUrl")
  val httpProtocol = http.baseURL(targetHostBaseUrl)

  val memberId = 2
  val memberUsername = "dental_demo_2"

  val scn = scenario("StatsServiceFunctionalTest")
    // Appointment
    .exec(
    http("appointment-reminder")
      .get("/appointment/getReminderStats?memberId=" + memberId + "&date=2016-10-01"))
    .exec(
      http("appointment-daily")
        .get("/appointment/getDailyStats?memberId=" + memberId + "&startDate=2016-09-01&endDate=2016-09-7"))
    .exec(
      http("appointment-confirmation")
        .get("/appointment/getConfirmationStats?memberId=" + memberId + "&startDate=2016-09-01&endDate=2016-09-7"))

    // Healthgrades
    .exec(
    http("healthgrade-daily")
      .get("/healthgrade/getDaily?memberId=" + memberId + "&date=2016-09-01"))
    .exec(
      http("healthgrade-rating-summary")
        .get("/healthgrade/getRatingSummary?memberId=" + memberId + "&currentDate=2016-09-01"))
    .exec(
      http("healthgrade-recent-survey")
        .get("/healthgrade/getRecentSurvey?memberId=" + memberId + "&topN=10"))
    .exec(
      http("healthgrade-survey")
        .get("/healthgrade/getSurvey?memberId=" + memberId + "&startDate=2016-09-01&endDate=2016-09-7"))
    .exec(
      http("healthgrade-doctor-ratings")
        .get("/healthgrade/getDoctorRatings?memberId=" + memberId))

    // Pay Per Click
    .exec(
      http("payperclick-getMonthlyStats")
        .get("/payperclick/getMonthlyStats" +
          "?memberId=" + memberId +
          "&attributes=Clicks,CostPerClick,TotalSpent" +
          "&fromMonth=2016-01-01" +
          "&toMonth=2016-06-01"))

    // SEO
    .exec(
      http("seo-monthly-keyword-rankings")
        .get("/seo/getMonthlyKeywordRankings?memberId=" + memberId + "&currentDate=2016-09-01&topN=10"))
    .exec(
      http("seo-monthly-city-rankings")
        .get("/seo/getMonthlyCityRankings?memberId=" + memberId + "&currentDate=2016-09-01&topN=10"))
    .exec(
      http("seo-monthly-stats")
        .get("/seo/getMonthlySeoStats" +
          "?memberId=" + memberId +
          "&attributes=OrganicCallsTotal,OrganicCallsNew,OrganicCallsCurrent" +
          "&fromMonth=2016-09-01" +
          "&toMonth=2016-10-01" +
          "&topN=10"))

    // Social
    .exec(
      http("social-monthly-facebook")
        .get("/social/getMonthlyFBStats?memberId=" + memberId + "&startDate=2016-01-01&endDate=2016-10-01"))
    .exec(
      http("social-monthly-stats")
        .get("/social/getMonthlySocialStats" +
          "?memberId=" + memberId +
          "&attributes=AverageDailyVisits,TotalVisitsOrganic,FacebookInteractions" +
          "&startDate=2016-09-01" +
          "&endDate=2016-10-01"))

    // Website
    .exec(
      http("website-daily-visits")
        .get("/website/getDailyVisits?memberId=" + memberId + "&startDate=2016-09-01&endDate=2016-10-01"))
    .exec(
      http("website-monthly-refers")
        .get("/website/getMonthlyReferringSites?memberId=" + memberId + "&currentDate=2016-09-01&topN=5"))
    .exec(
      http("website-monthly-stats")
        .get("/website/getWebsiteStats" +
          "?memberId=" + memberId +
          "&websiteAttributes=DailyTotalVisits,TotalVisits,AverageTimeOnsite" +
          "&fromDate=2016-09-01" +
          "&toDate=2016-10-01" +
          "&topN=5"))

    // Util
    .exec(
      http("util-update-member")
        .get("/util/updateMemberStats?userName=" + memberUsername))
    .exec(
      http("util-extract-for-member")
        .get("/util/extractSamuraiMemberStats" +
          "?userName=" + memberUsername +
          "&year=2016" +
          "&month=09"))
    .exec(
      http("util-extract-all-members")
        .get("/util/extractSamuraiStats" +
          "?year=2016" +
          "&month=09"))

  setUp(scn.inject(atOnceUsers(1)).protocols(httpProtocol))
}
