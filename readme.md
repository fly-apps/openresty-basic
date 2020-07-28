# Running OpenResty on Fly
If you've been developing web applications for long, you've probably heard of [Nginx](https://nginx.org/en/). It's an extremely popular open-source HTTP server, but it has some limitations. By default, Nginx doesn't provide a way to program logical operators or write custom features. Developers can circumvent this by using modules like [Nginx JavaScript](https://www.nginx.com/blog/introduction-nginscript/) or [Lua](https://github.com/openresty/lua-nginx-module), but that takes extra work to install and configure.

[OpenResty](https://openresty.org/en/) allows you to build full-fledged web applications on Nginx by bundling it with a Lua compiler and several other common modules. This makes OpenResty more broadly useful than vanilla Nginx, but depending on your use case, it might be overkill.

For example, if you want to [run a simple reverse proxy](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/) on your server, Nginx can handle it for you. But, if you want to add rate limiting, authentication, advanced caching, or a connection to a database, you'll need a solution like OpenResty. With the increase in distributed computing and microservices, OpenResty has become a great option for complex firewalls, API gateways, and even full-fledged web applications.

Typically, OpenResty is deployed to a central server. Web requests go through the OpenResty server before being routed to the relevant backing services, but this model isn't great for performance or redundancy. While you can set up and maintain several servers to run your OpenResty instance, you have to figure out how to keep updates and data in sync across them.

A better solution is to use a distributed hosting platform like [Fly](https://fly.io) to run your OpenResty installation at the edge. Using Fly will decrease latency while ensuring that the failure of a single node doesn't make your website unavailable.

## How to Deploy OpenResty to Fly
In this tutorial, you'll see how to create an OpenResty application and deploy it to Fly. You'll create a reverse proxy endpoint that uses the [JSON Placeholder API](https://jsonplaceholder.typicode.com/) as a backend service. You'll use a custom Lua script to add rate limiting, and the Fly Redis connection to add authentication to your endpoint. All the steps you need are in this tutorial, but if you'd like to download the final application, it's [available on Github](https://github.com/karllhughes/fly-openresty) as well.

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

Open the `fly.toml` file and set the `internal_port = 80` within the `[[services]]` portion:

```toml
...
[[services]]
  internal_port = 80
  protocol = "tcp"
...
```

This will route traffic through Fly to your container's port 80 where OpenResty will run.

### Configuring the Dockerfile
Fly will build and run your Docker image as a container on the edge, but you need to update your Dockerfile first.

OpenResty provides [a number of Docker images](https://github.com/openresty/docker-openresty) you can use for your application. I selected Centos and because of [an apparent bug in their Docker image](https://github.com/openresty/docker-openresty/issues/124), specified the `1.15.8.1-4-centos` tag.

After selecting the base image, add a `RUN` command to append `env FLY_REDIS_CACHE_URL` to the top of your `/usr/local/openresty/nginx/conf/nginx.conf` file. This ensures that Nginx has access to the `FLY_REDIS_CACHE_URL` environment variable.

Finally, remove the default Nginx site configuration files and add `proxy.conf` and `split.lua` to the `/etc/nginx/conf.d/` directory. When done, your Dockerfile should look something like this:

```dockerfile
# Using this base image because of: https://github.com/openresty/docker-openresty/issues/124
FROM openresty/openresty:1.15.8.1-4-centos

# Add the REDIS connection URL as an env variable in NGINX
RUN echo -e "env FLY_REDIS_CACHE_URL;\n$(cat /usr/local/openresty/nginx/conf/nginx.conf)" > /usr/local/openresty/nginx/conf/nginx.conf

# Add the configuration and lua files
RUN rm /etc/nginx/conf.d/*
COPY proxy.conf /etc/nginx/conf.d/proxy.conf
COPY split.lua /etc/nginx/conf.d/split.lua
```

Now that your Dockerfile is ready, you just need to create the `proxy.conf` site configuration and `split.lua` Lua file before you deploy it to Fly.

### Creating the Nginx Site Configuration



  - Connecting to a backing service
  - Adding Rate Limiting with Lua: https://github.com/openresty/lua-resty-limit-traffic
  - Adding caching with Redis: https://github.com/openresty/lua-resty-redis

## Conclusion

