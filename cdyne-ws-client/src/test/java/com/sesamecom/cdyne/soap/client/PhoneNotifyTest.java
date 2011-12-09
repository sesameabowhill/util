package com.sesamecom.cdyne.soap.client;

import java.util.Locale;
import junit.framework.Test;
import junit.framework.TestCase;
import junit.framework.TestSuite;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;

/**
 * Unit tests for PhoneNotify
 */
public class PhoneNotifyTest extends TestCase {

    private static final Log log = LogFactory.getLog(PhoneNotifyTest.class);

    protected long queueId = -1;

    /**
     * Create the test case
     *
     * @param testName name of the test case
     */
    public PhoneNotifyTest( String testName ) {
        super( testName );
    }

    /**
     * @return the suite of tests being tested
     */
    public static Test suite() {
        return new TestSuite( PhoneNotifyTest.class );
    }

    /**
     * Rigourous Test :-)
     */
    public void testPhoneNotify() {

        String phoneToCall = System.getProperty("phoneToCall");
        String licenseKey = System.getProperty("licenseKey");
        String textToSay = System.getProperty("textToSay");
        if(textToSay == null)
            textToSay = "Hey baby, want to party?";

        System.out.println("calling: "+phoneToCall+" with licence key: "+licenseKey+" to say: ["+textToSay+"]");

        PhoneNotifyService service = new PhoneNotifyServiceAxis2Impl();
        queueId = service.notifyPhoneAdvanced(
                phoneToCall, // phoneNumberToDial
                null, // transferNumber
                1, // voiceId 0=female 1=male
                "11234567890", // callerIdNumber
                "Maven Johnson", // callerIdName
                textToSay, // textToSay
                licenseKey, // licenseKey
                1, // tryCount
                0, // nextTryInSeconds
                new DateTime().withZone(DateTimeZone.UTC).toCalendar(Locale.US), // utcScheduledDateTime
                Short.parseShort("1"), // TTSRate
                Short.parseShort("100"), // TTSVolume
                "http://fakostatuscatcher.sesamecommunications.com/cdyne/call-status/TestCallStatusCatcher.cgi" // statusChangePostUrl
                );

        log.debug("queueId = "+queueId);
        assertTrue( queueId > -1 );
    }

    public void testGetSound() {
        String licenseKey = System.getProperty("licenseKey");
        String textToSay = System.getProperty("textToSay");
        if(textToSay == null)
            textToSay = "Maven";

        System.out.println("converting: "+textToSay+" with licence key: "+licenseKey+" to sound");

        PhoneNotifyService service = new PhoneNotifyServiceAxis2Impl();
        assertNotNull(service.getTTSinULAW(textToSay, 1, new Short("1"), new Short("100"), licenseKey));
    }
}
