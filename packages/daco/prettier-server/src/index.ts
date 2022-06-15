import * as express from 'express'
import { AddressInfo } from 'node:net'
import * as os from 'node:os'
import * as prettier from 'prettier'
const cluster = require('node:cluster')

if (!cluster.isWorker) {
  for (var i = 0; i < os.cpus().length; i++) {
    cluster.fork({ LOG_PORT: i == 0 })
  }
} else {
  startServer().then((port) => {
    if (process.env['LOG_PORT'] === 'true') {
      // Log the port we are listening on so the process that started the server
      // can connect to it, but only from the first worker. All other workers will use
      // the same port.
      console.log(JSON.stringify({ port }))
    }
  })
}

function startServer(): Promise<number> {
  const app = express()

  app.use(express.json())

  app.post('/format', formatRequestHandler())

  return new Promise((resolve) => {
    const server = app.listen(0, () => {
      resolve((server.address() as AddressInfo).port)
    })
  })
}

interface FormatRequest {
  source: string
  options: prettier.Options
}

function formatRequestHandler(): express.RequestHandler {
  return (req, res) => {
    const request = req.body as FormatRequest

    try {
      res.send({
        result: prettier.format(request.source, request.options),
      })
    } catch (error) {
      res.status(409).send({ error: error.message })
    }
  }
}
