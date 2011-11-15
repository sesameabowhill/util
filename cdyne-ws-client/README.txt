to test:

mvn -DphoneToCall=<enter 10 digit number> -DlicenseKey=F1A49B73-1B6D-4AA9-AF9A-D41FCFA08F89 clean test

optionally, you can include textToSay:

mvn -DtextToSay="<your text to say>" -DphoneToCall=<enter 10 digit number> -DlicenseKey=F1A49B73-1B6D-4AA9-AF9A-D41FCFA08F89 clean test
