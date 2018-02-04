module.exports = {
    hipchatRoom: 3733141,
    hipchatToken: 'AFzqrSSFwfkUig8wtU50llp1rx93URzLRJs9Zdpx',
    eventTopicArns: {
        cloudWatch: '${hipchat_cloudwatch_topic_arn}',
        codeDeploy: '${hipchat_codedeploy_topic_arn}',
    }
}