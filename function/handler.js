"use strict";

const puppeteer = require("puppeteer");

module.exports = async (event, context) => {
  const browser = await puppeteer.launch({
    args: ["--no-sandbox", "--disable-setuid-sandbox"],
  });
  const page = await browser.newPage();

  await page.goto("https://en.wikipedia.org/wiki/%22Hello,_World!%22_program");

  const firstPar = await page.$eval("#mw-content-text p", (el) => el.innerText);

  await browser.close();
  return context
    .status(200)
    .headers({ "Content-Type": "application/json" })
    .succeed({ result: firstPar });
};
