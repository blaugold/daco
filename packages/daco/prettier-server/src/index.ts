import * as express from 'express'
import { AddressInfo } from 'net'
import * as prettier from 'prettier'

const app = express()

app.use(express.json())

app.post('/format', formatRequestHandler())

const server = app.listen(() => {
  // Log the port we are listening on so the process that started the server
  // can connect to it.
  console.log(JSON.stringify({ port: (server.address() as AddressInfo).port }))
})

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
