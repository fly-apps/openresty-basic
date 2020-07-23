# Running OpenResty on Fly

- Introduction
  - What is OpenResty? - An overview of the tool, and its relationship to NGINX/Lua.
  - Why use OpenResty? - Some common reasons people might use OpenResty (microservices, caching, scripting on top of Nginx, etc.)
  - Why OpenResty on Fly? - Specific reasons that deploying OpenResty to edge hosting like Fly might be advantageous: speed, failover
- How to Run OpenResty on Fly
  - Setting up a new Fly app
  - Configuring the Dockerfile
  - Connecting to a backing service
  - Adding Rate Limiting with Lua: https://github.com/openresty/lua-resty-limit-traffic
  - Adding caching with Redis: https://github.com/openresty/lua-resty-redis
- Conclusion


-----

docker build -t karllhughes/fly-openresty . && docker run -it --rm -p 8000:80 --name=fly-openresty karllhughes/fly-openresty
