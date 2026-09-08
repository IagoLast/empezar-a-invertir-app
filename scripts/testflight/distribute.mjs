import { readFileSync } from 'node:fs';
import { sign } from 'node:crypto';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { setTimeout as sleep } from 'node:timers/promises';

export async function distributeBuild({ request, bundleId, version, groupId, wait = sleep, attempts = 45 }) {
  const apps = await request(`/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
  if (apps.data?.length !== 1) throw Error('Expected exactly one app for the bundle ID');
  const appId = apps.data[0].id;
  const groupApp = await request(`/v1/betaGroups/${groupId}/app`);
  if (groupApp.data?.id !== appId) throw Error('Tester group belongs to another app');
  let build;
  for (let attempt = 0; attempt < attempts; attempt++) {
    const result = await request(`/v1/builds?filter[app]=${appId}&filter[version]=${encodeURIComponent(version)}`);
    build = result.data?.find(row => row.attributes?.version === version);
    if (build?.attributes.processingState === 'VALID') break;
    if (['FAILED','INVALID'].includes(build?.attributes.processingState)) throw Error('Apple rejected build processing');
    console.log(`Waiting for Apple to process build ${version}`);
    await wait(20000);
  }
  if (build?.attributes.processingState !== 'VALID') throw Error('Apple processing did not finish within the distribution timeout');
  await request(`/v1/betaGroups/${groupId}/relationships/builds`, 'POST', { data: [{type:'builds',id:build.id}] });
  let next = `/v1/betaGroups/${groupId}/builds?limit=200`, assigned = false;
  while (next && !assigned) {
    const builds = await request(next);
    assigned = builds.data?.some(row => row.id === build.id) === true;
    const link = builds.links?.next ? new URL(builds.links.next) : null;
    next = link ? link.pathname + link.search : null;
  }
  if (!assigned) throw Error('Build assignment was not confirmed');
  for (let attempt = 0; attempt < attempts; attempt++) {
    const detail = await request(`/v1/builds/${build.id}/buildBetaDetail`);
    if (detail.data?.attributes.internalBuildState === 'IN_BETA_TESTING') {
      console.log(`Build ${version} is available to the internal tester group`);
      return build.id;
    }
    await wait(20000);
  }
  throw Error('Internal testing availability was not confirmed');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const keyId = process.env.ASC_KEY_ID, issuer = process.env.ASC_ISSUER_ID;
  const bundleId = process.env.IOS_BUNDLE_ID || 'com.empezarainvertir.app';
  const version = process.env.TESTFLIGHT_BUILD_NUMBER || `${process.env.GITHUB_RUN_NUMBER}.${process.env.GITHUB_RUN_ATTEMPT}`;
  const groupId = process.env.TESTFLIGHT_GROUP_ID;
  if (!keyId || !issuer || !groupId || !/^\d+(\.\d+)*$/.test(version)) throw Error('Missing TestFlight distribution configuration');
  const directory = process.env.TESTFLIGHT_SIGNING_DIR || join(process.env.RUNNER_TEMP, 'empezar-signing');
  const key = readFileSync(process.env.APPLE_PRIVATE_KEY_PATH || join(directory,'private_keys',`AuthKey_${keyId}.p8`));
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const request = async (path, method='GET', body) => {
    const now = Math.floor(Date.now()/1000);
    const data = `${encode({alg:'ES256',kid:keyId,typ:'JWT'})}.${encode({iss:issuer,iat:now,exp:now+600,aud:'appstoreconnect-v1'})}`;
    const token = `${data}.${sign('sha256',Buffer.from(data),{key,dsaEncoding:'ieee-p1363'}).toString('base64url')}`;
    const response = await fetch(`https://api.appstoreconnect.apple.com${path}`, {method,
      headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},
      body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(15000)});
    if (!response.ok) throw Error(`App Store Connect ${method} ${path}: HTTP ${response.status}`);
    return response.status === 204 ? null : response.json();
  };
  await distributeBuild({request,bundleId,version,groupId});
}
