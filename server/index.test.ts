import { describe, expect, test } from 'bun:test';
import { createHandler } from './index';

const token = 'a-private-test-token-that-is-long-enough';
const place = { id: 'ChIJ_test', displayName: { text: 'A coffee shop' }, location: { latitude: 40.7, longitude: -74 } };

function fixture(overrides = {}) {
    const calls: unknown[][] = [];
    const google = {
        async searchPlaces(...args: unknown[]) { calls.push(args); return [place]; },
        async placeDetails(...args: unknown[]) { calls.push(args); return place; },
        async placePhoto(...args: unknown[]) { calls.push(args); return new Response('image bytes', { headers: { 'Content-Type': 'image/jpeg' } }); },
        ...overrides,
    };
    return { handler: createHandler(google, token), calls };
}

function request(path: string, authorized = true) {
    return new Request(`http://localhost:8787${path}`, { headers: authorized ? { Authorization: `Bearer ${token}` } : {} });
}

describe('private script bridge', () => {
    test('blocks unauthorized requests before invoking Google', async () => {
        const { handler, calls } = fixture();
        expect((await handler(request('/search?q=coffee', false))).status).toBe(401);
        expect(calls).toHaveLength(0);
    });

    test('passes device/map coordinates to the script without host geolocation', async () => {
        const { handler, calls } = fixture();
        const response = await handler(request('/search?q=coffee%20%26%20tea&latitude=40.7&longitude=-74&radius=2500'));
        expect(await response.json()).toEqual({ places: [place] });
        expect(calls).toEqual([['coffee & tea', { center: { latitude: 40.7, longitude: -74 }, distance: 2500, limit: 20 }]]);
        expect(response.headers.get('Cache-Control')).toBe('no-store');
    });

    test('rejects invalid locations and resource paths before making billable requests', async () => {
        const { handler, calls } = fixture();
        for (const path of [
            '/search?q=coffee&latitude=NaN&longitude=0',
            '/search?q=coffee&latitude=91&longitude=0',
            '/search?q=coffee&latitude=0',
            '/details?id=..%2Fsecret',
            '/photo?name=https%3A%2F%2Fevil.example',
            '/photo?name=places%2Ftest%2Fphotos%2Ftest&width=1.5',
        ]) expect((await handler(request(path))).status).toBe(400);
        expect(calls).toHaveLength(0);
    });

    test('fetches details with photos and proxies bytes without a key or redirect', async () => {
        const { handler, calls } = fixture();
        expect(await (await handler(request('/details?id=ChIJ_test'))).json()).toEqual(place);
        const photo = await handler(request('/photo?name=places%2FChIJ_test%2Fphotos%2Fabc&width=900'));
        expect(photo.headers.get('Content-Type')).toBe('image/jpeg');
        expect(photo.headers.get('Location')).toBeNull();
        expect(await photo.text()).toBe('image bytes');
        expect(calls).toEqual([['places/ChIJ_test', { photos: true }], ['places/ChIJ_test/photos/abc', 900]]);
    });

    test('keeps upstream error bodies and secrets out of client responses', async () => {
        const { handler } = fixture({ searchPlaces: async () => { throw new Error('Google Places API 403: sensitive upstream body'); } });
        const response = await handler(request('/search?q=coffee&latitude=0&longitude=0'));
        expect(response.status).toBe(502);
        const text = await response.text();
        expect(text).toContain('403');
        expect(text).not.toContain('sensitive upstream body');
    });
});
