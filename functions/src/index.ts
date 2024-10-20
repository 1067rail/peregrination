import * as functions from "@google-cloud/functions-framework";

functions.http("helloHttp", (req, res) => {
  res.send("hello, world\n");
});
