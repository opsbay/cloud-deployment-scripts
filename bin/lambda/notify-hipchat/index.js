var http = require('https')
var config = require('./config')

const requestOptions = {
    host: 'api.hipchat.com',
    port: 443,
    method: 'POST',
    path: `/v2/room/${config.hipchatRoom}/notification?auth_token=${config.hipchatToken}`,
    headers: {
        'Content-Type': 'application/json',
    }
}

const isCloudWatchEvent = (eventArn) => {
    if(eventArn.includes(config.eventTopicArns.cloudWatch)) {
        return true
    }
    return false
}

const isCodeDeployEvent = (eventArn) => {
    if(eventArn.includes(config.eventTopicArns.codeDeploy)) {
        return true
    }
    return false
}

const sendNotification = ({message, color}, context) => {
    console.log(message)
    const request = http.request(requestOptions, function(response) {
        response.setEncoding('utf8')
        response.on('data', (chunk) => console.error(`BODY:\n${chunk}`))
        response.on('end', () => {
            console.info(`Status Code: ${response.statusCode}`)
            if (response.statusCode === 204) {
                console.log('Success!')
                context.succeed(`Notification sent to room ${config.hipchatRoom} successfully.`)
            } else {
                console.error('Hipchat API Error!')
                context.fail(`Notification failed to be sent to room ${config.hipchatRoom}.`)
            }
        })
    })
    request.on('error', (error) => {
        console.error(`Unable to complete request: ${error.message}`)
        context.fail(`Notification failed to be sent to room ${config.hipchatRoom}.`)
    })
    request.write(JSON.stringify({
        message,
        color,
        notify: true,
        message_format: 'html',
    }))
    request.end()
}

const parseCloudWatchEvent = (event, context) => {
    const message = JSON.parse(event.Records[0].Sns.Message)
    const region = event.Records[0].EventSubscriptionArn.split(":")[3];
	const subject = "AWS CloudWatch Notification"
	const alarmName = message.AlarmName
	const metricName = message.Trigger.MetricName
	const newState = message.NewStateValue
	const alarmReason = message.NewStateReason
	let color = 'purple'

	if (message.NewStateValue === "ALARM") {
		color = "red"
	} else if (message.NewStateValue === "OK") {
		color = "green"
	}

	return {
		message: `<b>${subject} - ${alarmName}</b><p>${newState} - ${metricName}</p><em>${alarmReason}</em><p><a href="https://console.aws.amazon.com/cloudwatch/home?region=${region}#alarm:alarmFilter=ANY;name=${encodeURIComponent(alarmName)}">View Alarm</a></p>`,
		color: color,
	}
}

const parseCodeDeployEvent = (event, context) => {
    const title = "AWS CodeDeploy Notification"
    const message = JSON.parse(event.Records[0].Sns.Message)
    const subject = event.Records[0].Sns.Subject;
    let hipchatMessage = `<b>${title}</b><p>${subject}</p>`
	let color = 'purple'

    if (message.instanceStatus) {
        hipchatMessage = `<b>AWS CodeDeploy Instance Event</b><p>${subject}</p><p>${message.eventTriggerName}</p><p><a href="https://console.aws.amazon.com/codedeploy/home?region=${message.region}#/deployments/${message.deploymentId}/instances/${message.instanceId}/events">View Instance Events</a></p>`
        if (message.instanceStatus === "Succeeded") {
            color = "green"
        } else if (message.instanceStatus === "Failed") {
            color = "red"
        }
    } else if (message.status) {
        hipchatMessage = `<b>AWS CodeDeploy Deployment Event - ${message.applicationName} (${message.deploymentGroupName})</b><p>${message.eventTriggerName}</p><p>${subject}</p><p>Application: ${message.applicationName}</p><p>Deployment Group: ${message.deploymentGroupName}</p><p><a href="https://console.aws.amazon.com/codedeploy/home?region=${message.region}#/deployments/${message.deploymentId}">View Deployment</a></p>`
        if (message.status === "SUCCEEDED") {
            color = "green"
        } else if (message.status === "FAILED") {
            color = "red"
        }
    }

	return {
		message: hipchatMessage,
		color: color,
	}
}

const processEvent = (event, context) => {
    console.info(`Event Received: ${JSON.stringify(event, null, 2)}`)
    let message = {}

    if(event && event.Records && Array.isArray(event.Records)) {
        console.info('Event Type: SNS')
        const eventSubscriptionArn = event.Records[0].EventSubscriptionArn

        // CloudWatch SNS Event
        if (isCloudWatchEvent(eventSubscriptionArn)) {
            console.info('SNS Event Subtype: CloudWatch')
            message = parseCloudWatchEvent(event, context)
        } else if (isCodeDeployEvent(eventSubscriptionArn)) {
            console.info('SNS Event Subtype: CodeDeploy')
            message = parseCodeDeployEvent(event, context)
        } else {
            console.info('SNS Event Subtype: Unknown')
            context.fail('Unknown SNS event subtype was received.')
        }
    } else {
        console.info('Event Type: Unknown')
        context.fail('Unknown event type was received.')
    }
    
    sendNotification(message, context)
}

exports.handler = function(event, context) {
    processEvent(event, context)
}
