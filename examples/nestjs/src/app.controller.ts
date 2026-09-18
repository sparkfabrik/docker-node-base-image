import { Controller, Get } from "@nestjs/common";

@Controller()
export class AppController {
  @Get()
  hello(): string {
    return "Hello from NestJS on the SparkFabrik Node.js base image";
  }
}
