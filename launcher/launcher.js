'use strict'

import { ECSClient, UpdateServiceCommand } from "@aws-sdk/client-ecs"
import parser from "lambda-multipart-parser"

const isValidPassword = (request) => {
  const password = process.env.password

  return request.password === password
}

export async function handler(event, context, callback) {
  // Get password from form data
  const request = await parser.parse(event)
  if (!isValidPassword(request)) {
    console.log("Password did not match, not launching")

    callback(null, {
      statusCode: 403,
      body: "Forbidden",
    })
    return
  }

  const desiredCount = 1
  console.log(`Altering launched tasks count to ${desiredCount}`)

  const client = new ECSClient({region: process.env.region})
  const input = {
    cluster: process.env.cluster,
    service: process.env.service,
    desiredCount: 1
  }
  const command = new UpdateServiceCommand(input)
  await client.send(command)

  const response = {
    statusCode: 200,
    body: "Launching!",
  }
  callback(null, response)
}
