import { ECSClient, UpdateServiceCommand } from "@aws-sdk/client-ecs"

export async function handler(event, context, callback) {
  const desiredCount = 1
  console.log(`Altering launched tasks count to ${desiredCount}`)

  const client = new ECSClient({region: process.env.region})
  const input = {
    cluster: process.env.cluster,
    service: process.env.service,
    desiredCount: 1
  }
  const command = new UpdateServiceCommand(input)
  const response = await client.send(command)

  callback(null, 'great success')
}
