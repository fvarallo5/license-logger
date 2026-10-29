/** SPA passthrough so Workers Builds always has a `main` entry-point. */
export default {
  async fetch(request, env) {
    return env.ASSETS.fetch(request);
  },
};
