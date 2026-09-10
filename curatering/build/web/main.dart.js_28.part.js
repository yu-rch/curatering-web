((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,G,E,F,B={
L3(d){return new B.L2(d)},
yb(){var x=C.e.m("https://curatering.up.railway.app"),w=x.length
if(w===0)return""
return C.e.iL(x,"/")?C.e.ai(x,0,w-1):x},
ce2(d){var x,w,v=C.e.m(d)
if(C.e.b7(v,"data:")){x=C.e.e6(v,",")
if(x>=0)v=C.e.bZ(v,x+1)}w=A.b7("\\s+",!0,!1,!1)
return A.bQ(v,w,"")},
aaf(d){if(d==null)return null
return C.e.m(J.w(d)).toUpperCase()},
aO4(d){var x,w=A.qp(d)
if(w==null||w.gq6()!=="image.runpod.ai"||w.gt2().length<3)return d
if(C.f.ga9(w.gt2())!=="google-nano-banana-2-edit"||C.f.gaU(w.gt2())!=="result.png")return d
x=w.gt2()[1]
return B.yb()+"/api/public/runpod/image/result/"+A.f7(2,x,C.ba,!1)},
cu7(d){var x=A.qp(d)
return x!=null&&C.e.q(x.ghB(),"/api/public/runpod/image/result/")},
ce_(d){var x,w,v,u=null,t=d.h(0,"id"),s=t==null?u:J.w(t)
if(s!=null&&s.length!==0)return s
t=d.h(0,"jobId")
x=t==null?u:J.w(t)
if(x!=null&&x.length!==0)return x
w=d.h(0,"job")
if(y.f.b(w)){t=w.h(0,"id")
v=t==null?u:J.w(t)
if(v!=null&&v.length!==0)return v}return u},
c5r(d){var x,w,v,u,t,s=d.c,r=s==null?"Request failed":s
try{x=C.a4.bu(A.cF(A.cE(d.e)).ba(d.w),null)
if(y.f.b(x)){if(J.n(x.h(0,"code"),"runpod_not_configured")){v=A.bA("AI generation is not configured on the server. Set RUNPOD_API_KEY and RUNPOD_ENDPOINT_ID on Railway.")
throw A.p(v)}if(x.h(0,"message")!=null)r=A.h(x.h(0,"message"))}}catch(u){w=A.a8(u)
if(y.L.b(w))throw A.p(w)
v=d.e
t=d.w
if(A.cF(A.cE(v)).ba(t).length!==0)r=A.cF(A.cE(v)).ba(t).length>500?C.e.ai(A.cF(A.cE(v)).ba(t),0,500)+"\u2026":A.cF(A.cE(v)).ba(t)}throw A.p(A.bA("HTTP "+d.b+": "+A.h(r)))},
c5q(d,e){var x,w,v=null,u=d==null?v:C.e.m(J.w(d))
if(u==null||u.length===0)return v
if(C.e.b7(u,"http://")||C.e.b7(u,"https://"))return B.aO4(u)
if(C.e.b7(u,"data:image/"))return u
if(!e)return v
x=B.ce2(u)
if(x.length<100)return v
w=A.b7("^[A-Za-z0-9+/]+={0,2}$",!0,!1,!1)
if(!w.b.test(x))return v
return"data:image/png;base64,"+x},
CC(d){var x,w,v,u,t,s,r,q=null
if(d==null)return q
if(typeof d=="string")return B.c5q(d,!1)
if(y.j.b(d)){for(x=J.bb(d);x.A();){w=B.CC(x.gR())
if(w!=null)return w}return q}x=y.f
if(!x.b(d))return q
v=A.aD(d,y.N,y.z)
for(u=0;u<14;++u){t=D.b6u[u]
s=B.c5q(v.h(0,t),t==="image")
if(s!=null)return s}for(u=0;u<6;++u){s=B.c5q(v.h(0,D.bdN[u]),!0)
if(s!=null)return s}for(u=0;u<6;++u){w=B.CC(v.h(0,D.b7L[u]))
if(w!=null)return w}for(u=0;u<4;++u){w=B.CC(v.h(0,D.bcX[u]))
if(w!=null)return w}r=v.h(0,"diagnostics")
if(x.b(r)){w=B.CC(r)
if(w!=null)return w}return q},
SL(d){var x,w,v,u,t,s,r=null
if(d==null)return r
if(y.j.b(d)){for(x=J.bb(d);x.A();){w=B.SL(x.gR())
if(w!=null)return w}return r}if(!y.f.b(d))return r
v=A.aD(d,y.N,y.z)
x=v.h(0,"status")
if(x==null)x=v.h(0,"state")
u=C.e.m(A.h(x==null?"":x)).toLowerCase()
x=v.h(0,"message")
if(x==null)x=v.h(0,"error")
if(x==null)x=v.h(0,"detail")
w=C.e.m(A.h(x==null?"":x))
if(u==="error"||u==="failed"||u==="cancelled"||u==="canceled")return w.length===0?"Worker returned status "+u+".":w
if(w.length!==0){x=A.b7("error|failed",!1,!1,!1)
x=x.b.test(w)}else x=!1
if(x)return w
for(t=0;t<5;++t){s=B.SL(v.h(0,D.b8O[t]))
if(s!=null)return s}return r},
ce1(d){var x=B.aaf(d.h(0,"status"))
if(x==null)x="UNKNOWN"
return"AI job completed but returned no image URL. status="+x+", output="+new B.aO1().$1(d.h(0,"output"))},
yc(d,e,f,g,h,i,j){return B.cuc(d,e,f,g,h,i,j)},
cuc(a4,a5,a6,a7,a8,a9,b0){var x=0,w=A.l(y.T),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3
var $async$yc=A.m(function(b1,b2){if(b1===1){t.push(b2)
x=u}for(;;)switch(x){case 0:u=4
if(B.yb().length===0)A.aq(A.bA("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
g=y.N
s=A.H(g,y.z)
J.az(s,"prompt",a4)
J.az(s,"num_inference_steps",a8)
J.dY(s,a5)
r=s
J.az(r,"guidance_scale",a6)
q=b0==null?null:C.e.m(b0)
if(q!=null&&q.length!==0)J.az(r,"user_id",q)
f=C.e.m(a7)
p=f
if(p!=null&&p.length!==0){J.az(r,"init_image_base64",B.ce2(p))
J.az(r,"strength",a9)}s=r
e=s.h(0,"task_type")
s=e==null?s.h(0,"task"):e
o=C.e.m(A.h(s==null?"":s)).toLowerCase()==="nano_event_design"
s=A.bE(B.yb()+"/api/public/runpod/run",0,null)
e=A.Q(["Content-Type","application/json"],g,g)
d=y.P
x=7
return A.d(A.eF(s,C.a4.cr(A.Q(["input",r],g,d),null),null,e).cM(C.qB),$async$yc)
case 7:n=b2
x=n.b===200?8:10
break
case 8:s=n
m=d.a(C.a4.bu(A.cF(A.cE(s.e)).ba(s.w),null))
l=B.aaf(J.t(m,"status"))
k=B.ce_(m)
x=l==="COMPLETED"?11:12
break
case 11:a0=B.CC(J.t(m,"output"))
j=a0==null?B.CC(m):a0
x=j!=null?13:14
break
case 13:x=B.cu7(j)?15:16
break
case 15:x=17
return A.d(B.I3(j),$async$yc)
case 17:case 16:v=j
x=1
break
case 14:a1=B.SL(J.t(m,"output"))
i=a1==null?B.SL(m):a1
if(i!=null){s=B.L3(i)
throw A.p(s)}x=k!=null&&k.length!==0?18:19
break
case 18:s=o?B.yb()+"/api/public/runpod/image/result/"+A.f7(2,k,C.ba,!1):null
x=20
return A.d(B.CD(k,s),$async$yc)
case 20:s=b2
v=s
x=1
break
case 19:s=B.L3(B.ce1(m))
throw A.p(s)
case 12:x=k!=null&&k.length!==0?21:22
break
case 21:s=o?B.yb()+"/api/public/runpod/image/result/"+A.f7(2,k,C.ba,!1):null
x=23
return A.d(B.CD(k,s),$async$yc)
case 23:s=b2
v=s
x=1
break
case 22:s=l
if(s==="FAILED"||s==="CANCELLED"){s=A.bA(B.aO2(m))
throw A.p(s)}s=J.t(m,"error")
if(s==null)s=J.t(m,"message")
s=A.bA("Generation failed: "+A.h(s==null?"No job id from RunPod":s))
throw A.p(s)
x=9
break
case 10:B.c5r(n)
case 9:u=2
x=6
break
case 4:u=3
a3=t.pop()
h=A.a8(a3)
s=A.bA("Failed to generate image: "+A.h(h))
throw A.p(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$yc,w)},
aO2(d){var x=d.h(0,"error"),w=x==null?null:J.w(x)
if(w==null)w="Unknown error"
if(C.e.q(w,"executionTimeout"))return"AI generation exceeded the server time limit (~10 min). Redeploy the RunPod worker image, then try again \u2014 the second attempt is usually faster."
return"Job failed: "+w},
CD(d,e){return B.cu8(d,e)},
cu8(a5,a6){var x=0,w=A.l(y.T),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$CD=A.m(function(a7,a8){if(a7===1){t.push(a8)
x=u}for(;;)switch(x){case 0:a2=0
a3=null
k=y.L,j=y.z,i=y.P,h=a6!=null
case 3:if(!(a2<130)){x=4
break}x=5
return A.d(A.hH(D.qD,null,j),$async$CD)
case 5:++a2
u=7
x=10
return A.d(A.hb(A.bE(B.yb()+"/api/public/runpod/status/"+A.f7(2,a5,C.ba,!1),0,null),null).cM(H.fh),$async$CD)
case 10:s=a8
if(s.b===429){g=A.bA("Too many requests \u2014 wait a moment and try again.")
throw A.p(g)}x=s.b===200?11:12
break
case 11:g=s
r=i.a(C.a4.bu(A.cF(A.cE(g.e)).ba(g.w),null))
q=B.aaf(J.t(r,"status"))
x=q==="COMPLETED"?13:14
break
case 13:f=B.CC(J.t(r,"output"))
p=f==null?B.CC(r):f
x=p!=null?15:16
break
case 15:e=A.qp(p)
x=e!=null&&C.e.q(e.ghB(),"/api/public/runpod/image/result/")?17:18
break
case 17:x=19
return A.d(B.I3(p),$async$CD)
case 19:case 18:g=p
v=g
x=1
break
case 16:d=B.SL(J.t(r,"output"))
o=d==null?B.SL(r):d
if(o!=null){g=B.L3(o)
throw A.p(g)}x=h?20:21
break
case 20:x=22
return A.d(B.I3(a6),$async$CD)
case 22:v=a6
x=1
break
case 21:g=B.L3(B.ce1(r))
throw A.p(g)
case 14:g=q
if(g==="FAILED"||g==="CANCELLED"){g=A.bA(B.aO2(r))
throw A.p(g)}case 12:u=2
x=9
break
case 7:u=6
a4=t.pop()
g=A.a8(a4)
if(g instanceof B.L2)throw a4
else if(k.b(g)){n=g
m=J.w(n)
if(J.jv(m,"Job failed")||J.jv(m,"AI generation exceeded")||J.jv(m,"Worker returned"))throw a4
a3=n
A.a1B("Polling error (attempt "+A.h(a2)+"): "+A.h(n))}else{l=g
a3=l
g=A.h(a2)
a1=A.h(l)
A.a1B("Polling error (attempt "+g+"): "+a1)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(k.b(a3))throw A.p(a3)
throw A.p(A.bA("Job timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$CD,w)},
I3(d){return B.cua(d)},
cua(d){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j
var $async$I3=A.m(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:l=null
k=null
q=y.z,p=y.t,o=0
case 3:if(!(o<12)){x=5
break}u=7
x=10
return A.d(A.hb(A.bE(d,0,null),null).cM(C.f_),$async$I3)
case 10:s=f
if(s.b===200){x=1
break}k=s.b
if(!C.f.q(A.a([404,425,429,500,502,503,504],p),s.b)){n=B.L3("Generated image result is unavailable (HTTP "+s.b+").")
throw A.p(n)}u=2
x=9
break
case 7:u=6
j=t.pop()
n=A.a8(j)
if(n instanceof B.L2)throw j
else{r=n
l=r}x=9
break
case 6:x=2
break
case 9:x=11
return A.d(A.hH(D.qD,null,q),$async$I3)
case 11:case 4:++o
x=3
break
case 5:if(k!=null)throw A.p(B.L3("Generated image result is not ready yet (HTTP "+A.h(k)+"). Try again in a moment."))
q=l
throw A.p(B.L3("Generated image result is not ready yet: "+A.h(q==null?"unknown error":q)))
case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$I3,w)},
L2:function L2(d){this.a=d},
aO1:function aO1(){},
kv(d,e,f,g,h,i,j,k,l,m){return new B.A9(e,f,h,j,k,l,d,i,m,g,null)},
b3e:function b3e(d,e){this.a=d
this.b=e},
A9:function A9(d,e,f,g,h,i,j,k,l,m,n){var _=this
_.d=d
_.e=e
_.r=f
_.x=g
_.z=h
_.as=i
_.cx=j
_.cy=k
_.db=l
_.dx=m
_.a=n},
b3g:function b3g(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0,a1,a2,a3,a4,a5){var _=this
_.fr=d
_.fx=e
_.fy=f
_.go=g
_.k1=_.id=$
_.a=h
_.b=i
_.c=j
_.d=k
_.e=l
_.f=m
_.r=n
_.w=o
_.x=p
_.y=q
_.z=r
_.Q=s
_.as=t
_.at=u
_.ax=v
_.ay=w
_.ch=x
_.CW=a0
_.cx=a1
_.cy=a2
_.db=a3
_.dx=a4
_.dy=a5},
b3h:function b3h(d){this.a=d}},D,H
J=c[1]
A=c[0]
C=c[2]
G=c[46]
E=c[30]
F=c[42]
B=a.updateHolder(c[20],B)
D=c[54]
H=c[55]
B.L2.prototype={
j(d){return this.a},
$ico:1}
B.b3e.prototype={
O(){return"_ChipVariant."+this.b}}
B.A9.prototype={
D(d){var x,w,v,u,t,s,r=this,q=null,p=E.ca4(d)
A.a5(d)
x=r.r
w=x!=null
v=r.x
u=r.e
if(u==null)u=v?p.ch:q
t=p.y
if(t==null){A.a5(d)
t=!0}s=r.z
if(s==null)s=p.f
return E.a9g(!1,q,C.dy,q,r.cx,q,q,C.v,q,new B.b3g(d,w,v,D.jy,q,q,q,q,q,q,q,q,q,!0,q,q,q,q,F.kH,q,q,q,q,q,q,q,q),q,q,q,q,q,q,q,q,w,r.d,q,u,r.dx,q,q,q,x,r.cy,q,v,s,q,q,q,t,r.as,q,!0,q,r.db)}}
B.b3g.prototype={
gii(){var x,w=this,v=w.id
if(v===$){x=A.a5(w.fr)
w.id!==$&&A.aZ()
v=w.id=x.ax}return v},
gdq(){if(this.go===D.jy)var x=0
else x=this.fx?1:0
return x},
gyO(){return 1},
gfK(){var x,w,v,u=this,t=u.k1
if(t===$){x=A.a5(u.fr)
u.k1!==$&&A.aZ()
t=u.k1=x.ok}x=t.as
if(x==null)x=null
else{if(u.fx)if(u.fy){w=u.gii()
v=w.as
w=v==null?w.z:v}else{w=u.gii()
v=w.rx
w=v==null?w.k3:v}else w=u.gii().k3
w=x.bX(w)
x=w}return x},
gcB(){return new A.ba(new B.b3h(this),y.b)},
gbN(){if(this.go===D.jy)var x=C.ap
else{x=this.gii().x1
if(x==null)x=C.T}return x},
gbS(){return C.ap},
grr(){var x,w,v=this
if(v.fx)if(v.fy){x=v.gii()
w=x.as
x=w==null?x.z:w}else x=v.gii().b
else x=v.gii().k3
return x},
grA(){var x,w,v=this
if(v.fx)if(v.fy){x=v.gii()
w=x.as
x=w==null?x.z:w}else{x=v.gii()
w=x.rx
x=w==null?x.k3:w}else x=v.gii().k3
return x},
gec(){var x,w,v=this
if(v.go===D.jy&&!v.fy)if(v.fx){x=v.gii()
w=x.to
if(w==null){w=x.B
x=w==null?x.k3:w}else x=w
x=new A.am(x,1,C.C,-1)}else{x=v.gii().k3
x=new A.am(A.au(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255),1,C.C,-1)}else x=F.l9
return x},
ghh(){var x,w,v=this,u=null
if(v.fx)if(v.fy){x=v.gii()
w=x.as
x=w==null?x.z:w}else x=v.gii().b
else x=v.gii().k3
return new A.eR(18,u,u,u,u,x,u,u,u)},
gci(){return C.cy},
grT(){var x=this.gfK(),w=x==null?null:x.r
if(w==null)w=14
x=A.bT(this.fr,C.bI)
x=x==null?null:x.gcf()
x=A.pB(C.ej,G.eF,A.a1((x==null?C.bo:x).bi(w)/14-1,0,1))
x.toString
return x}}
var z=a.updateTypes([])
B.aO1.prototype={
$1(d){var x
if(y.f.b(d)){x=d.gds()
x=x.o3(x,12)
return x.b_(x,", ")}if(y.j.b(d))return"list("+J.ay(d)+")"
if(d==null)return"null"
return A.m8(J.ax(d).a,null)},
$S:13}
B.b3h.prototype={
$1(d){var x,w,v=this
if(d.q(0,C.an)&&d.q(0,C.ar)){x=v.a
if(x.go===D.jy){x=x.gii().k3
x=A.au(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}else{x=x.gii().k3
x=A.au(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}return x}if(d.q(0,C.ar)){x=v.a
if(x.go===D.jy)x=null
else{x=x.gii().k3
x=A.au(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}return x}if(d.q(0,C.an)){x=v.a
if(x.go===D.jy){x=x.gii()
w=x.Q
x=w==null?x.y:w}else{x=x.gii()
w=x.Q
x=w==null?x.y:w}return x}x=v.a
if(x.go===D.jy)x=null
else{x=x.gii()
w=x.p3
x=w==null?x.k2:w}return x},
$S:18};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.L2,A.X)
w(A.eG,[B.aO1,B.b3h])
x(B.b3e,A.j5)
x(B.A9,A.an)
x(B.b3g,A.qZ)})()
A.hO(b.typeUniverse,JSON.parse('{"L2":{"co":[]},"A9":{"an":[],"f":[]}}'))
var y=(function rtii(){var x=A.ac
return{L:x("co"),s:x("B<e>"),t:x("B<u>"),j:x("a0<@>"),P:x("S<e,@>"),f:x("S<@,@>"),N:x("e"),b:x("ba<O?>"),z:x("@"),T:x("e?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.qD=new A.bx(5e6)
D.e0=new A.ad(0,10,0,10)
D.b6u=x(["image_url","imageUrl","public_url","publicUrl","url","image","output_url","outputUrl","output_image_url","outputImageUrl","result_url","resultUrl","generated_image_url","generatedImageUrl"],y.s)
D.b7L=x(["images","image_urls","imageUrls","artifacts","files","predictions"],y.s)
D.b8O=x(["output","result","data","diagnostics","errors"],y.s)
D.bcX=x(["output","result","data","prediction"],y.s)
D.bdN=x(["image_base64","imageBase64","b64_json","base64","image_data","imageData"],y.s)
D.ft=new A.bn(6,null,null,null)
D.jy=new B.b3e(0,"flat")})()};
(a=>{a["ZbbXubPJnMuJ1SIKyJl5ALhh4Fw="]=a.current})($__dart_deferred_initializers__);