
import {
  error,       // creates error responses
  json,        // creates JSON responses
  Router,      // the ~440 byte router itself
} from 'itty-router'

// Create a new router
const router = Router();


export interface Env {
  CF_API_TOKEN: string;
  CF_API_ZONE: string;
  test: KVNamespace;
  // MY_DURABLE_OBJECT: DurableObjectNamespace;
  // MY_BUCKET: R2Bucket;
  // MY_SERVICE: Fetcher;
  // MY_QUEUE: Queue;
  // DB: D1Database;
}

async function
  delete_subdomain(record_id: string, zone_id: string, zone_token: string) {
  const options = {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': "Bearer " + zone_token
    }
  };

  fetch("https://api.cloudflare.com/client/v4/zones/" + zone_id +
    "/dns_records/" + record_id,
    options)
    .then(response => response.json())
    .then(response => console.log(response))
    .catch(err => console.error(err));
}

async function delete_all_subdomains(zone_id: string, zone_token: string) {
  const options = {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
      "Authorization": "Bearer " + zone_token,
    }
  };

  fetch("https://api.cloudflare.com/client/v4/zones/" + zone_id + "/dns_records/" + record_id,
    options)
    .then(response => response.json())
    .then(response => console.log(response))
    .catch(err => console.error(err));
}

async function get_all_ips(zone_id: string, zone_token: string) {
  return fetch("https://api.cloudflare.com/client/v4/zones/" + zone_id + "/dns_records",
    {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer " + zone_token,
      }
    })
    .then(response => response.json())
    // .then(response => { return response; })
    .catch(err => console.error(err));
}

async function registerIP(ip: string, zone_id: string, zone_token: string) {
  let timestampInSeconds = Math.floor(Date.now() / 1000);

  const data = {
    "content": ip,
    "name": "test",
    "proxied": true,
    "type": "A",
    "ttl": "300",
  }

  try {
    const subdomain_name = "fast-" + timestampInSeconds.toString();
    data["name"] = subdomain_name;

    const response = await fetch("https://api.cloudflare.com/client/v4/zones/" +
      zone_id + "/dns_records",
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer " + zone_token
        },
        body: JSON.stringify(data)
      });

    const result = await response.json();
    console.log("register ip " + ip + ":", JSON.stringify(result));

    const init = {
      headers: {
        "content-type": "application/json;charset=UTF-8",
      },
    };

    if (result["success"] == false) {
      return new Response("Failed to register IP " + ip + ": " +
        result.errors[0].message + ", " +
        result.errors[0].error_chain[0].message);
    } else {
      return new Response(result.result.name);
    }

    // return new Response(subdomain_name, init);

  } catch (error) {
    console.error("Error:", error);
  }
}

router.get('/', (req: Request, env: Env, ctx: ExecutionContext) => {
  // console.log(env.test)
  // env.test.get("visitor_count").then((value) => {
  //   let c = 0;
  //   if (value != null) { c = parseInt(value) + 1; }
  //   env.test.put("visitor_count", (c + 1).toString());
  // });


  return new Response(
    'Hello, world! This is the root page of your Worker template. ' +
    env.CF_API_ZONE);
});

router.get("/getallips/", (req: Request, env: Env, ctx: ExecutionContext) => {
  return get_all_ips(env.CF_API_ZONE, env.CF_API_TOKEN)
    .then(response => { console.log(response); return response; })
});

router.get('/register/', (req: Request, env: Env, ctx: ExecutionContext) => {
  // // Decode text like "Hello%20world" into "Hello world"
  // let ip = decodeURIComponent(params.ip);
  // // Serialise the input into a base64 string
  // let base64 = btoa(input);

  const { searchParams } = new URL(req.url);
  const ip = searchParams.get("ip")

  if (ip == null) {
    return new Response(
      "No IP specified, usage https://fastscp.com/register?ip=120.10.10.1");
  }

  return registerIP(ip, env.CF_API_ZONE, env.CF_API_TOKEN);
});

/*
This shows a different HTTP method, a POST.

Try send a POST request using curl or another tool.

Try the below curl command to send JSON:

$ curl -X POST <worker> -H "Content-Type: application/json" -d '{"abc": "def"}'
*/
router.post(
  '/post', async request => {
    // Create a base object with some fields.
    let fields = {
      asn: request.cf.asn,
      colo: request.cf.colo,
    };

    // If the POST data is JSON then attach it to our response.
    if (request.headers.get('Content-Type') == 'application/json') {
      let json = await request.json();
      Object.assign(fields, { json });
    }

    // Serialise the JSON to a string.
    const returnData = JSON.stringify(fields, null, 2);

    return new Response(returnData, {
      headers: {
        'Content-Type': 'application/json',
      },
    });
  });

// router.all('*', () => new Response('404, not found!', { status: 404 }));

// export default {
//   fetch: router.handle,
// };

export default {
  fetch:
    (request: Request, env: Env, ctx: ExecutionContext) => router.handle(request, env, ctx)
      .then(json)     // send as JSON
      .catch(error),  // catch errors
}

// const handler: ExportedHandler = {

// };

// export default handler;

const handler2: ExportedHandler = {
  // The scheduled handler is invoked at the interval set in our wrangler.toml's
  // [[triggers]] configuration.
  async scheduled(event: ScheduledEvent, env: Env, ctx: ExecutionContext): Promise<void> {
    // A Cron Trigger can make requests to other endpoints on the Internet,
    // publish to a Queue, query a D1 Database, and much more.
    //
    // We'll keep it simple and make an API call to a Cloudflare API:
    let resp = await fetch('https://api.cloudflare.com/client/v4/ips');
    let wasSuccessful = resp.ok ? 'success' : 'fail';

    // You could store this result in KV, write to a D1 Database, or publish to a
    // Queue. In this template, we'll just log the result:
    console.log(`trigger fired at ${event.cron} : $ { wasSuccessful }`);
  }
  ,
}
  ;
