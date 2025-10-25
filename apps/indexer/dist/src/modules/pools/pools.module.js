"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PoolsModule = void 0;
const common_1 = require("@nestjs/common");
const pools_service_1 = require("./pools.service");
const pools_controller_1 = require("./pools.controller");
const prisma_service_1 = require("../../database/prisma.service");
let PoolsModule = class PoolsModule {
};
exports.PoolsModule = PoolsModule;
exports.PoolsModule = PoolsModule = __decorate([
    (0, common_1.Module)({
        providers: [pools_service_1.PoolsService, prisma_service_1.PrismaService],
        controllers: [pools_controller_1.PoolsController],
        exports: [pools_service_1.PoolsService],
    })
], PoolsModule);
//# sourceMappingURL=pools.module.js.map