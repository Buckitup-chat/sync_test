export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname.startsWith("/api/")) {
      const newUrl = new URL(
        "http://buckitup.xyz:4403" + url.pathname.replace("/api", "")
      );
      newUrl.search = url.search;

      const backendRequest = new Request(newUrl, {
        method: request.method,
        headers: request.headers,
        body: request.body,
      });

      if (request.method === "OPTIONS") {
        const headers = new Headers();
        headers.set("Access-Control-Allow-Origin", "*");
        headers.set(
          "Access-Control-Allow-Methods",
          "GET, POST, PUT, DELETE, OPTIONS"
        );
        headers.set(
          "Access-Control-Allow-Headers",
          "Content-Type, Authorization"
        );
        return new Response(null, {
          status: 200,
          statusText: "OK",
          headers,
        });
      }

      try {
        const response = await fetch(backendRequest);

        const headers = new Headers(response.headers);
        headers.set("Access-Control-Allow-Origin", "*");
        headers.set(
          "Access-Control-Allow-Methods",
          "GET, POST, PUT, DELETE, OPTIONS"
        );
        headers.set(
          "Access-Control-Allow-Headers",
          "Content-Type, Authorization"
        );

        const newResponse = new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers,
        });

        return newResponse;
      } catch (error) {
        return new Response("Backend unavailable", { status: 503 });
      }
    }

    return fetch(request);
  },
};
