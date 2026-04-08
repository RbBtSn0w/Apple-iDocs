#!/usr/bin/env node
import { encoding_for_model } from "js-tiktoken";

const text = process.argv.slice(2).join(" ") || "";
const enc = encoding_for_model("gpt-4o");
const tokens = enc.encode(text).length;
process.stdout.write(String(tokens));
