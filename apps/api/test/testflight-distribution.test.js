import test from 'node:test';
import assert from 'node:assert/strict';
import {distributeBuild} from '../../../scripts/testflight/distribute.mjs';
test('distribution waits for the exact build and verifies internal availability', async()=>{
  let polls=0,assigned=false;
  const request=async(path,method,body)=>{
    if(path.startsWith('/v1/apps?'))return {data:[{id:'app'}]};
    if(path.endsWith('/app'))return {data:{id:'app'}};
    if(path.startsWith('/v1/builds?')){polls++;return {data:[{id:'build',attributes:{version:'7.1',processingState:polls>1?'VALID':'PROCESSING'}}]};}
    if(method==='POST'){assert.equal(body.data[0].id,'build');assigned=true;return;}
    assert.ok(assigned);
    if(path.includes('/builds?limit='))return {data:[{id:'build'}]};
    return {data:{attributes:{internalBuildState:'IN_BETA_TESTING'}}};
  };
  assert.equal(await distributeBuild({request,bundleId:'bundle',version:'7.1',groupId:'group',wait:async()=>{}}),'build');
  assert.equal(polls,2);
});
test('distribution rejects groups from a different app before writing',async()=>{
  await assert.rejects(distributeBuild({bundleId:'bundle',version:'7.1',groupId:'group',request:async(path,method)=>{
    assert.notEqual(method,'POST');return path.startsWith('/v1/apps?')?{data:[{id:'app'}]}:{data:{id:'wrong'}};
  }}),/another app/);
});
