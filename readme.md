# Running OpenResty on Fly
<!---- cut here --->
If you've been developing web applications for long, you've probably heard of [Nginx](https://nginx.org/en/). It's a widely used open-source HTTP server, but it has some limitations. By default, Nginx doesn't provide a way to program logical operators or write custom logic. Developers can circumvent this by using modules like [Nginx JavaScript](https://www.nginx.com/blog/introduction-nginscript/) or [Lua](https://github.com/openresty/lua-nginx-module), but that takes extra work to install and configure.

[OpenResty](https://openresty.org/en/) allows you to build full-fledged web applications by bundling Nginx with a Lua compiler and several common modules. This makes OpenResty more broadly useful than vanilla Nginx, but depending on your use case, it could be overkill.

For example, if you want to [run a simple reverse proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/) on your server, Nginx can handle it. If you need to add rate limiting, authentication, advanced caching, or a connection to a database, you'll need a solution like OpenResty. With the increase in distributed computing and microservices, OpenResty has become an excellent option for complex firewalls, API gateways, and even full-fledged web applications.

Typically, OpenResty is deployed to a central server. Web requests go through OpenResty before being routed to the relevant backing services, but this model isn't great for performance or redundancy. While you can set up several servers and run OpenResty on each, you have to figure out how to maintain and sync data across them.

A better solution is to use a distributed hosting platform like [Fly](https://fly.io) to run OpenResty at the edge. Using Fly will decrease latency while ensuring that a single node's failure doesn't make your website unavailable.

![Running OpenResty on Fly.io](https://github.com/fly-examples/openresty-basic/raw/main/fly-2020-07-29-a.jpg)

## How to Deploy OpenResty to Fly
In this tutorial, you'll see how to create an OpenResty application and deploy it to Fly. You'll create a reverse proxy endpoint that uses the [JSON Placeholder API](https://jsonplaceholder.typicode.com/) as a backend service. You'll use a custom Lua script to add rate limiting, and the Fly Redis connection to add API key authentication to your endpoint. All the steps you need are in this tutorial, but if you'd like to download the final application, it's [available on Github](https://github.com/karllhughes/fly-openresty) as well.

### Prerequisites
- [Flyctl command line tool](https://fly.io/docs/flyctl/installing/).

### Creating a New Fly Application
First, you'll need to use `flyctl` to create a new application. If you haven't already, install the appropriate version of `flyctl` for your operating system using the [instructions here](https://fly.io/docs/hands-on/installing/).

Next, [sign up](https://fly.io/docs/hands-on/sign-up/) or [sign in](https://fly.io/docs/hands-on/sign-in/) to your Fly account via the command line:

```bash
# Sign up
flyctl auth signup

# Or sign in
flyctl auth login
```

You will be directed to a web page that will allow you to log in using your Github account or email and password.

Create a new directory called `fly-openresty` and create your new app inside of it:

```bash
mkdir fly-openresty && cd fly-openresty
flyctl apps create
```

Use the auto-generated app name, select your organization, and select `Dockerfile` as your builder. You should see output similar to this in your console:

```bash
? App Name (leave blank to use an auto-generated name) 

? Select organization: YOUR ORGANIZATION

? Select builder: Dockerfile
    (Create an example Dockerfile)

New app created
  Name     = <your-app-name>  
  Owner    = <your-name>
  Version  = 0               
  Status   =                 
  Hostname = <empty>         

Wrote config file fly.toml
```

Fly will create a `fly.toml` file and `Dockerfile` in the root of your project.

Open the `fly.toml` file and set the `internal_port = 80` within the `[[services]]` portion of the file:

```toml
...
[[services]]
  internal_port = 80
  protocol = "tcp"
...
```

This will route traffic through Fly to your container's port 80, where OpenResty will run.

### Configuring the Dockerfile
Fly will build and run your Docker image as a container on the edge, but you need to update your Dockerfile first.

OpenResty provides [several Docker images](https://github.com/openresty/docker-openresty) you can use for your application. I opted for Centos, but because of [an apparent bug in their Docker image](https://github.com/openresty/docker-openresty/issues/124), specified the `1.15.8.1-4-centos` tag.

After selecting the base image, add a `RUN` command to append `env FLY_REDIS_CACHE_URL` to the top of your `/usr/local/openresty/nginx/conf/nginx.conf` file. This line ensures that Nginx has access to the `FLY_REDIS_CACHE_URL` environment variable.

Finally, remove the default Nginx site configuration files and add `default.conf` file to the `/etc/nginx/conf.d/` directory. When done, your Dockerfile should look something like this:

```dockerfile
# Using this base image because of: https://github.com/openresty/docker-openresty/issues/124
FROM openresty/openresty:1.15.8.1-4-centos

# Add the REDIS connection URL as an env variable in NGINX
RUN echo -e "env FLY_REDIS_CACHE_URL;\n$(cat /usr/local/openresty/nginx/conf/nginx.conf)" > /usr/local/openresty/nginx/conf/nginx.conf

# Add the configuration file
RUN rm /etc/nginx/conf.d/*
COPY default.conf /etc/nginx/conf.d/default.conf
```

Now that your Dockerfile is ready, you need to create the `default.conf` file before you can deploy your application to Fly.

### Setting up the Nginx Configuration
Before you add rate limiting and Redis to your Nginx configuration, you can start with a simple reverse proxy configuration.

To set up your reverse proxy, create a `default.conf` file in your root directory and add the following:

```conf
server {
    listen 80;
    location /api/ {
        proxy_pass http://jsonplaceholder.typicode.com/posts/;
    }
}
```

This minimal Nginx configuration reverse proxies any request to `/api/` to the JSON Placeholder API. To test it, you can deploy this to Fly using the command line:

```bash
flyctl deploy
```

You should see Fly build your Docker image and push it to Fly to deploy it. When finished, you'll see output similar to the following:

```bash
Deploying <your-app-name>
==> Validating App Configuration
--> Validating App Configuration done
Services
TCP 80/443 ⇢ 80

Deploy source directory '/Users/karl/fly-openresty'
Docker daemon available, performing local build...
==> Building with Dockerfile
Using Dockerfile: /Users/karl/fly-openresty/Dockerfile
...
--> Done Pushing Image
==> Optimizing Image
--> Done Optimizing Image
==> Creating Release
Release v1 created
Monitoring Deployment
You can detach the terminal anytime without stopping the deployment

1 desired, 1 placed, 1 healthy, 0 unhealthy [health checks: 1 total, 1 passing]
--> v1 deployed successfully
```

Your reverse proxy is now live on Fly! You can visit it and see the JSON Placeholder data at `https://<your-app-name>.fly.dev/api/`, but you're not done yet. In the next two sections, you'll see how to add rate limiting and authentication using a Redis store and custom Lua scripts.

### Adding Rate Limiting
Nginx reads and applies all the configuration files in the `/etc/nginx/conf.d/` directory. Because OpenResty adds the Lua compiler to Nginx, you can write [Lua code](http://www.lua.org/) inside your `default.conf` file. To add rate limiting, you can use the [lua-resty-limit-traffic](https://github.com/openresty/lua-resty-limit-traffic) library that comes with OpenResty and customize its behavior in your Nginx configuration file.

Open your `default.conf` file and replace it with the following:

```conf
lua_shared_dict my_limit_req_store 100m;

server {
    listen 80;
    location /api/ {
        access_by_lua_block {
            -- RATE LIMITER --
            local limit_req = require "resty.limit.req"

            -- Allow .5 requests per second --
            local lim, err = limit_req.new("my_limit_req_store", .5, .5)
            if not lim then
                ngx.log(ngx.ERR, "failed to instantiate a resty.limit.req object: ", err)
                return ngx.exit(500)
            end

            -- Use the visitor's IP addres as a key --
            local key = ngx.var.http_fly_client_ip
            local delay, err = lim:incoming(key, true)

            -- Throw an error when the limit is reached --
            if err == "rejected" then
                ngx.log(ngx.ERR, "Limit reached: ", err)
                return ngx.exit(503)
            end
        }

        proxy_pass http://jsonplaceholder.typicode.com/posts/;
    }
}
```

This configuration passes your request through using the `proxy_pass` directive at the end, as the previous version did. Before it does, it checks if the visitor has reached their request limit using the `Fly-Client-IP` header [attached to the request by Fly](https://fly.io/docs/services/#http). If the IP address has called the endpoint in the past 2 seconds, it returns a 503 response and logs the error.

You can re-deploy this configuration file to Fly (again using `flyctl deploy`) and call the endpoint twice in quick succession to test it.

You've now got a working rate limiter, but you're still not finished. In the last section, you'll see how to connect your OpenResty application to Redis to store API keys that can be used for authentication. 

### Checking API Keys Against a Redis Store
Fly offers a [region-local Redis instance](https://fly.io/docs/redis/) to all deployments, which can be used to persist data for longer periods. While this volatile datastore is not meant for permanent use, you can use it to cache data so that it's accessible on the edge.

In this last step, you'll connect to the Fly Redis instance using the OpenResty [Redis driver](https://github.com/openresty/lua-resty-redis). You'll authenticate requests using a `key` passed in by the user through a query string argument and return a 401 response code if authentication fails. In a real application, you would probably push data to the Fly Redis instance using [their global data store](https://fly.io/docs/redis/#managing-redis-data-globally), but because this is a demonstration app, you'll hard code a few sample API keys.

First, write a Lua script to parse the connection string. Fly's `FLY_REDIS_CACHE_URL` must be split at the `:` and `@` characters, so you can write a function that takes any number of characters as possible delimiters ([credit to Walt Howard on Stack Overflow](https://stackoverflow.com/a/29497100/977192) for this one). Create a new file called `split.lua` and add the following:

```lua
local _M = {}
function _M.split(source, delimiters)
    local elements = {}
    local pattern = '([^'..delimiters..']+)'
    string.gsub(source, pattern, function(value) elements[#elements + 1] =     value;  end);
    return elements
end
return _M
```

Next, you need to make sure this file is copied into your Docker image, so open up your `Dockerfile` and add the following line to the end of it:

```dockerfile
...
COPY split.lua /etc/nginx/conf.d/split.lua
```

Finally, you're ready to update your `default.conf` file. Open it and edit it as shown below:

```conf
lua_shared_dict my_limit_req_store 100m;
lua_package_path "/etc/nginx/conf.d/?.lua;;";
-- Ensures that the Redis connection's DNS resolves --
resolver 8.8.8.8;

server {
    listen 80;
    location /api/ {
        access_by_lua_block {
            -- RATE LIMITER --
            ...

            -- REDIS CACHE --
            splitter = require("split")
            local redis_client = require "resty.redis"
            local redis = redis_client:new()

            redis:set_timeouts(1000, 1000, 1000)

            -- Split the connection string env variable --
            parts = splitter.split(os.getenv("FLY_REDIS_CACHE_URL"), ":@")

            -- Connect to Redis --
            local res, err = redis:connect(parts[4], parts[5])
            if not res then
                ngx.log(ngx.ERR, "failed to connect: ", err)
                return
            end

            -- Authorize using the password --
            local res, err = redis:auth(parts[3])
            if not res then
                ngx.log(ngx.ERR, "failed to authenticate: ", err)
                return
            end

            -- Set some allowed API keys --
            -- Note: This should be done outside this script in a real app --
            ok, err = redis:set("oVr0mDgJejSmb9jwXp6B", 1)
            ok, err = redis:set("AstIqxOHpyAToCwh8qeL", 2)
            ok, err = redis:set("eaFW03Pjp27ZbgqpgqJQ", 3)

            -- Lookup the `key` --
            local res, err = redis:get(ngx.var.arg_key)
            if (not res) or (res == ngx.null) then
                ngx.log(ngx.ERR, "Invalid key: ", err)
                return ngx.exit(401)
            end

            -- Close the connection --
            local res, err = redis:close()
            if not res then
                ngx.say("failed to close: ", err)
                return
            end
        }

        proxy_pass http://jsonplaceholder.typicode.com/posts/;
    }
}
```

Deploy this updated configuration file using `flyctl deploy` and visit `https://<your-app-name>.fly.dev/api/` again. This time, you will get a 401 response from OpenResty. Add one of the API keys you hard-coded as a `key` in the query string: `https://<your-app-name>.fly.dev/api/?key=AstIqxOHpyAToCwh8qeL` and you'll see the JSON placeholder data again.

## Conclusion
In this post, you've seen how to create an OpenResty application to extend Nginx's functionality. You've added rate-limiting to ensure that users don't abuse your API and simple authentication using data cached in Redis. Finally, by deploying the application on Fly, you can take advantage of their globally distributed edge hosting environment to make your app faster and more reliable than it would be on traditional hosting.

If you have any questions about using OpenResty with [Fly.io](https://fly.io/), be sure to reach out so we can help you get started.
