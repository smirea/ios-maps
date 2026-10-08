#!/usr/bin/env bun
import { timingSafeEqual } from 'node:crypto';
import { existsSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import type { searchPlaces, placeDetails, placePhoto } from '../../scripts/src/google-maps';

type GoogleMaps = {
    searchPlaces: typeof searchPlaces;
    placeDetails: typeof placeDetails;
    placePhoto: typeof placePhoto;
};

class RequestError extends Error {
    constructor(message: string, readonly status = 400) { super(message); }
}

const responseHeaders = { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' };

export function createHandler(google: GoogleMaps, token = '') {
    return async (request: Request): Promise<Response> => {
        const json = (value: unknown, status = 200) => Response.json(value, { status, headers: responseHeaders });
        try {
            if (token) {
                const actual = Buffer.from(request.headers.get('Authorization') ?? '');
                const expected = Buffer.from(`Bearer ${token}`);
                if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
                    throw new RequestError('The bridge access token is missing or incorrect. Update Search Connection.', 401);
                }
            }
            if (request.method !== 'GET') throw new RequestError('Only GET requests are supported.', 405);
            const url = new URL(request.url);
            switch (url.pathname) {
                case '/health':
                    return json({ status: 'ok', provider: 'google-maps-script' });
                case '/search': {
                    const query = required(url, 'q', 500);
                    const latitude = number(url, 'latitude', -90, 90);
                    const longitude = number(url, 'longitude', -180, 180);
                    const distance = url.searchParams.has('radius') ? number(url, 'radius', 1, 50_000) : 10_000;
                    const places = await google.searchPlaces(query, { center: { latitude, longitude }, distance, limit: 20 });
                    return json({ places });
                }
                case '/details': {
                    const id = required(url, 'id', 300);
                    if (!/^[A-Za-z0-9_-]+$/.test(id)) throw new RequestError('Invalid place ID.');
                    return json(await google.placeDetails(`places/${id}`, { photos: true }));
                }
                case '/photo': {
                    const name = required(url, 'name', 2000);
                    if (!/^places\/[A-Za-z0-9_-]+\/photos\/[A-Za-z0-9_-]+$/.test(name)) throw new RequestError('Invalid photo resource.');
                    const width = url.searchParams.has('width') ? number(url, 'width', 1, 4800) : 1200;
                    if (!Number.isInteger(width)) throw new RequestError('Photo width must be an integer.');
                    const image = await google.placePhoto(name, width);
                    const contentType = image.headers.get('Content-Type') ?? '';
                    if (!contentType.startsWith('image/')) throw new Error('Unexpected photo response.');
                    return new Response(image.body, { headers: { ...responseHeaders, 'Content-Type': contentType } });
                }
                default:
                    throw new RequestError('Endpoint not found.', 404);
            }
        } catch (error) {
            if (error instanceof RequestError) return json({ error: error.message }, error.status);
            const message = error instanceof Error ? error.message : '';
            const upstreamStatus = message.match(/(?:API |failed \()(\d{3})/u)?.[1];
            const detail = upstreamStatus ? ` Google returned ${upstreamStatus}; check your Places API key, billing, and quota.` : ' Check the script environment and your network connection.';
            return json({ error: `Google Maps could not complete this request.${detail}` }, 502);
        }
    };
}

function required(url: URL, name: string, maximum: number): string {
    const value = url.searchParams.get(name)?.trim();
    if (!value || value.length > maximum) throw new RequestError(`Provide ${name} (up to ${maximum} characters).`);
    return value;
}

function number(url: URL, name: string, minimum: number, maximum: number): number {
    const value = Number(required(url, name, 40));
    if (!Number.isFinite(value) || value < minimum || value > maximum) {
        throw new RequestError(`${name} must be between ${minimum} and ${maximum}.`);
    }
    return value;
}

function scriptsDirectory(): string {
    return process.env.GOOGLE_MAPS_SCRIPTS_DIR ?? `${process.env.HOME}/code/scripts`;
}

export function scriptsEnvFiles(scriptsDir = scriptsDirectory()): string[] {
    return ['.env', '.env.local'].flatMap(name => {
        const file = `${scriptsDir}/${name}`;
        return existsSync(file) ? [file] : [];
    });
}

async function relaunchWithScriptsEnv(files: string[]): Promise<number> {
    const args = [process.execPath, '--no-env-file'];
    for (const file of files) args.push('--env-file', file);
    args.push(import.meta.path, ...process.argv.slice(2));
    const child = Bun.spawn(args, {
        stdin: 'inherit',
        stdout: 'inherit',
        stderr: 'inherit',
        env: { ...process.env, MAPS_SERVER_ENV_LOADED: '1' },
    });
    return await child.exited;
}

if (import.meta.main) {
    try {
        if (process.env.MAPS_SERVER_ENV_LOADED !== '1') {
            const files = scriptsEnvFiles();
            if (files.length > 0) process.exit(await relaunchWithScriptsEnv(files));
            if (!process.env.GOOGLE_MAPS_API_KEY) {
                throw new Error(`Cannot load the Google Maps script environment from ${scriptsDirectory()}. Set GOOGLE_MAPS_SCRIPTS_DIR or export the scripts environment.`);
            }
        }
        const args = process.argv.slice(2);
        const options: Record<string, string> = {};
        const flags = new Set(['--host', '--port', '--script']);
        for (let index = 0; index < args.length; index += 2) {
            const key = args[index];
            const value = args[index + 1];
            if (!key || !flags.has(key) || !value || value.startsWith('--')) {
                throw new Error('Usage: bun server/index.ts [--host 127.0.0.1] [--port 8787] [--script /path/to/google-maps.ts]');
            }
            options[key] = value;
        }
        const hostname = options['--host'] ?? process.env.MAPS_SERVER_HOST ?? '127.0.0.1';
        const port = Number(options['--port'] ?? process.env.MAPS_SERVER_PORT ?? 8787);
        if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Choose a port between 1 and 65535.');
        const token = process.env.MAPS_BRIDGE_TOKEN ?? '';
        if (!['127.0.0.1', '::1', 'localhost'].includes(hostname) && token.length < 24) {
            throw new Error('For LAN access, set MAPS_BRIDGE_TOKEN to a random token of at least 24 characters.');
        }
        const script = options['--script'] ?? `${scriptsDirectory()}/src/google-maps.ts`;
        let google: GoogleMaps;
        try {
            google = await import(pathToFileURL(script).href);
        } catch {
            throw new Error('Cannot load the Google Maps script. Start the server with npm start so the scripts environment is loaded.');
        }
        if (typeof google.searchPlaces !== 'function' || typeof google.placeDetails !== 'function' || typeof google.placePhoto !== 'function') {
            throw new Error('Update ~/code/scripts: the Google Maps script must export searchPlaces, placeDetails, and placePhoto.');
        }
        const server = Bun.serve({ hostname, port, idleTimeout: 60, fetch: createHandler(google, token) });
        console.log(`Private Maps search bridge listening on ${server.url.origin}`);
        console.log(token ? 'Access token required. No searches or locations are logged.' : 'Loopback only. No searches or locations are logged.');
    } catch (error) {
        console.error(error instanceof Error ? error.message : 'Could not start the search bridge.');
        process.exit(1);
    }
}
