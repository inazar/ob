path = require 'path'
util = require 'util'
express = require 'express'
bodyParser = require 'body-parser'
assets = require 'connect-assets'
crypto = require 'crypto'
xmlparser = require 'express-xml-bodyparser'

api =
  public: '12d8f0a1-bdeb-4e1f-847a-11bc438c782b'
  secret: '03d556ca-bda2-4748-bbcb-88b3769afaef'
  api: 'aebb70c9-ca7a-443c-b88d-27638b65e601'

product =
  description: 'Dummy product'

customer =
  id: 'dummy'
  email: 'test@example.com'

#### Basic application initialization
# Create app instance.
app = express()
tracking = Object.create(null)

# Define Port
port = process.env.PORT or process.env.VMC_APP_PORT or 8088

#### View initialization
app.use assets({})

# Set View Engine.
app.set 'view engine', 'jade'

app.use xmlparser explicitArray: false
app.use bodyParser.urlencoded extended: false

app.get '/', (req, res) ->
  res.render 'index.jade',
    key: api.public
    query: req.query

app.get '/confirm', (req, res) -> res.redirect '/'

app.post '/confirm', (req, res) ->
  return res.redirect('/?error=No amount given') if not (amount = req.param('amount'))
  return res.redirect("/?error=Wrong amount: #{req.param('amount')}") if isNaN(amount = parseFloat amount) or amount <= 0
  amount = (Math.round(amount*100)/100).toFixed(2)
  now = new Date().toISOString()
  unique = crypto.createHash('md5').update(now).digest('hex')
  now = now.split('T')
  token = "#{now[0]} #{now[1].split('.')[0]} #{unique.substr(0, 10)}"
  hash = crypto.createHash('sha256').update(token+api.secret+unique+amount+'USD').digest('hex')
  console.log 'Tracking ID:', unique
  console.log 'Token:', token
  tracking[unique] =
    complete: false
    token: token
    amount: amount
    currency: 'USD'
  res.render 'confirm.jade',
    amount: amount
    currency: 'USD'
    description: product.description
    tracking: unique
    customer: customer.id
    email: customer.email
    key: api.public
    token: token
    hash: hash
    success: '/success'
    cancel: ''

app.get '/success', (req, res) ->
  transaction = tracking[req.query.tid]
  delete tracking[req.query.tid]
  res.render 'success.jade', transaction

app.post '/postback', (req, res) ->
  res.status(200).end()
  data = req.body.pwgc?.response
  return if not data?.payment
  console.log 'Postback:', util.inspect data, depth: null
  # Validate API key
  return console.log "API key is invalid: #{tmp}" if api.public isnt (tmp = data.payment.merchantData?.publicKey)
  # Authenticate the response
  return console.log "Authentication failed: #{tmp}" if data.payment.transaction?.pwgcHash isnt (tmp = crypto.createHash('sha256').update(api.public+':'+data.payment.transaction?.pwgcTrackingID+':'+api.secret).digest('hex'))
  # Validate the tracking id
  return console.log "Tracking ID unknown: #{tid}" if not (tid = data.payment.merchantData.merchantTrackingID) or not tracking[tid]
  # Validate the amount
  return console.log "Wrong amount: #{tmp}" if parseFloat(tracking[tid].amount) isnt parseFloat(tmp = data.payment.amount?.amountValue)
  # Validate the currency
  return console.log "Wrong currency: #{tmp}" if tracking[tid].currency isnt (tmp = data.payment.amount.currencyCode)
  # Validate the errorCode
  return console.log "Error code: #{tmp}" if '0' isnt (tmp = data.error?.errorCode)
  tracking[tid].complete = true
  tracking[tid].response = data

app.listen port, ->
  console.log "OB Test is listening on %d in '%s' mode", port, process.env.NODE_ENV || 'development'
