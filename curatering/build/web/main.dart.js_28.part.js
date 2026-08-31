((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,G,E,F,B={
L4(d){return new B.L3(d)},
yd(){var x=C.e.n("https://curatering.up.railway.app"),w=x.length
if(w===0)return""
return C.e.iG(x,"/")?C.e.ah(x,0,w-1):x},
cdi(d){var x,w,v=C.e.n(d)
if(C.e.b4(v,"data:")){x=C.e.dD(v,",")
if(x>=0)v=C.e.bQ(v,x+1)}w=A.b_("\\s+",!0,!1,!1)
return A.by(v,w,"")},
aaj(d){if(d==null)return null
return C.e.n(J.A(d)).toUpperCase()},
aO5(d){var x,w=A.qo(d)
if(w==null||w.gq4()!=="image.runpod.ai"||w.gt0().length<3)return d
if(C.f.gaa(w.gt0())!=="google-nano-banana-2-edit"||C.f.gaR(w.gt0())!=="result.png")return d
x=w.gt0()[1]
return B.yd()+"/api/public/runpod/image/result/"+A.f8(2,x,C.b9,!1)},
ctc(d){var x=A.qo(d)
return x!=null&&C.e.q(x.ghA(),"/api/public/runpod/image/result/")},
cdf(d){var x,w,v,u=null,t=d.h(0,"id"),s=t==null?u:J.A(t)
if(s!=null&&s.length!==0)return s
t=d.h(0,"jobId")
x=t==null?u:J.A(t)
if(x!=null&&x.length!==0)return x
w=d.h(0,"job")
if(y.f.b(w)){t=w.h(0,"id")
v=t==null?u:J.A(t)
if(v!=null&&v.length!==0)return v}return u},
c4z(d){var x,w,v,u,t,s=d.c,r=s==null?"Request failed":s
try{x=C.a4.bt(A.cA(A.cz(d.e)).b7(d.w),null)
if(y.f.b(x)){if(J.i(x.h(0,"code"),"runpod_not_configured")){v=A.bz("AI generation is not configured on the server. Set RUNPOD_API_KEY and RUNPOD_ENDPOINT_ID on Railway.")
throw A.p(v)}if(x.h(0,"message")!=null)r=A.h(x.h(0,"message"))}}catch(u){w=A.a9(u)
if(y.L.b(w))throw A.p(w)
v=d.e
t=d.w
if(A.cA(A.cz(v)).b7(t).length!==0)r=A.cA(A.cz(v)).b7(t).length>500?C.e.ah(A.cA(A.cz(v)).b7(t),0,500)+"\u2026":A.cA(A.cz(v)).b7(t)}throw A.p(A.bz("HTTP "+d.b+": "+A.h(r)))},
c4y(d,e){var x,w,v=null,u=d==null?v:C.e.n(J.A(d))
if(u==null||u.length===0)return v
if(C.e.b4(u,"http://")||C.e.b4(u,"https://"))return B.aO5(u)
if(C.e.b4(u,"data:image/"))return u
if(!e)return v
x=B.cdi(u)
if(x.length<100)return v
w=A.b_("^[A-Za-z0-9+/]+={0,2}$",!0,!1,!1)
if(!w.b.test(x))return v
return"data:image/png;base64,"+x},
CH(d){var x,w,v,u,t,s,r,q=null
if(d==null)return q
if(typeof d=="string")return B.c4y(d,!1)
if(y.j.b(d)){for(x=J.bc(d);x.A();){w=B.CH(x.gR())
if(w!=null)return w}return q}x=y.f
if(!x.b(d))return q
v=A.aI(d,y.N,y.z)
for(u=0;u<14;++u){t=D.b7_[u]
s=B.c4y(v.h(0,t),t==="image")
if(s!=null)return s}for(u=0;u<6;++u){s=B.c4y(v.h(0,D.bel[u]),!0)
if(s!=null)return s}for(u=0;u<6;++u){w=B.CH(v.h(0,D.b8f[u]))
if(w!=null)return w}for(u=0;u<4;++u){w=B.CH(v.h(0,D.bdu[u]))
if(w!=null)return w}r=v.h(0,"diagnostics")
if(x.b(r)){w=B.CH(r)
if(w!=null)return w}return q},
SR(d){var x,w,v,u,t,s,r=null
if(d==null)return r
if(y.j.b(d)){for(x=J.bc(d);x.A();){w=B.SR(x.gR())
if(w!=null)return w}return r}if(!y.f.b(d))return r
v=A.aI(d,y.N,y.z)
x=v.h(0,"status")
if(x==null)x=v.h(0,"state")
u=C.e.n(A.h(x==null?"":x)).toLowerCase()
x=v.h(0,"message")
if(x==null)x=v.h(0,"error")
if(x==null)x=v.h(0,"detail")
w=C.e.n(A.h(x==null?"":x))
if(u==="error"||u==="failed"||u==="cancelled"||u==="canceled")return w.length===0?"Worker returned status "+u+".":w
if(w.length!==0){x=A.b_("error|failed",!1,!1,!1)
x=x.b.test(w)}else x=!1
if(x)return w
for(t=0;t<5;++t){s=B.SR(v.h(0,D.b9l[t]))
if(s!=null)return s}return r},
cdh(d){var x=B.aaj(d.h(0,"status"))
if(x==null)x="UNKNOWN"
return"AI job completed but returned no image URL. status="+x+", output="+new B.aO2().$1(d.h(0,"output"))},
ye(d,e,f,g,h,i,j){return B.cth(d,e,f,g,h,i,j)},
cth(a4,a5,a6,a7,a8,a9,b0){var x=0,w=A.m(y.T),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3
var $async$ye=A.n(function(b1,b2){if(b1===1){t.push(b2)
x=u}for(;;)switch(x){case 0:u=4
if(B.yd().length===0)A.an(A.bz("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
g=y.N
s=A.H(g,y.z)
J.aG(s,"prompt",a4)
J.aG(s,"num_inference_steps",a8)
J.ey(s,a5)
r=s
J.aG(r,"guidance_scale",a6)
q=b0==null?null:C.e.n(b0)
if(q!=null&&q.length!==0)J.aG(r,"user_id",q)
f=C.e.n(a7)
p=f
if(p!=null&&p.length!==0){J.aG(r,"init_image_base64",B.cdi(p))
J.aG(r,"strength",a9)}s=r
e=s.h(0,"task_type")
s=e==null?s.h(0,"task"):e
o=C.e.n(A.h(s==null?"":s)).toLowerCase()==="nano_event_design"
s=A.bE(B.yd()+"/api/public/runpod/run",0,null)
e=A.Q(["Content-Type","application/json"],g,g)
d=y.P
x=7
return A.d(A.eH(s,C.a4.cs(A.Q(["input",r],g,d),null),null,e).cK(C.xR),$async$ye)
case 7:n=b2
x=n.b===200?8:10
break
case 8:s=n
m=d.a(C.a4.bt(A.cA(A.cz(s.e)).b7(s.w),null))
l=B.aaj(J.t(m,"status"))
k=B.cdf(m)
x=l==="COMPLETED"?11:12
break
case 11:a0=B.CH(J.t(m,"output"))
j=a0==null?B.CH(m):a0
x=j!=null?13:14
break
case 13:x=B.ctc(j)?15:16
break
case 15:x=17
return A.d(B.I8(j),$async$ye)
case 17:case 16:v=j
x=1
break
case 14:a1=B.SR(J.t(m,"output"))
i=a1==null?B.SR(m):a1
if(i!=null){s=B.L4(i)
throw A.p(s)}x=k!=null&&k.length!==0?18:19
break
case 18:s=o?B.yd()+"/api/public/runpod/image/result/"+A.f8(2,k,C.b9,!1):null
x=20
return A.d(B.CI(k,s),$async$ye)
case 20:s=b2
v=s
x=1
break
case 19:s=B.L4(B.cdh(m))
throw A.p(s)
case 12:x=k!=null&&k.length!==0?21:22
break
case 21:s=o?B.yd()+"/api/public/runpod/image/result/"+A.f8(2,k,C.b9,!1):null
x=23
return A.d(B.CI(k,s),$async$ye)
case 23:s=b2
v=s
x=1
break
case 22:s=l
if(s==="FAILED"||s==="CANCELLED"){s=A.bz(B.aO3(m))
throw A.p(s)}s=J.t(m,"error")
if(s==null)s=J.t(m,"message")
s=A.bz("Generation failed: "+A.h(s==null?"No job id from RunPod":s))
throw A.p(s)
x=9
break
case 10:B.c4z(n)
case 9:u=2
x=6
break
case 4:u=3
a3=t.pop()
h=A.a9(a3)
s=A.bz("Failed to generate image: "+A.h(h))
throw A.p(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$ye,w)},
aO3(d){var x=d.h(0,"error"),w=x==null?null:J.A(x)
if(w==null)w="Unknown error"
if(C.e.q(w,"executionTimeout"))return"AI generation exceeded the server time limit (~10 min). Redeploy the RunPod worker image, then try again \u2014 the second attempt is usually faster."
return"Job failed: "+w},
CI(d,e){return B.ctd(d,e)},
ctd(a5,a6){var x=0,w=A.m(y.T),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$CI=A.n(function(a7,a8){if(a7===1){t.push(a8)
x=u}for(;;)switch(x){case 0:a2=0
a3=null
k=y.L,j=y.z,i=y.P,h=a6!=null
case 3:if(!(a2<130)){x=4
break}x=5
return A.d(A.iw(D.qI,null,j),$async$CI)
case 5:++a2
u=7
x=10
return A.d(A.hd(A.bE(B.yd()+"/api/public/runpod/status/"+A.f8(2,a5,C.b9,!1),0,null),null).cK(H.fg),$async$CI)
case 10:s=a8
if(s.b===429){g=A.bz("Too many requests \u2014 wait a moment and try again.")
throw A.p(g)}x=s.b===200?11:12
break
case 11:g=s
r=i.a(C.a4.bt(A.cA(A.cz(g.e)).b7(g.w),null))
q=B.aaj(J.t(r,"status"))
x=q==="COMPLETED"?13:14
break
case 13:f=B.CH(J.t(r,"output"))
p=f==null?B.CH(r):f
x=p!=null?15:16
break
case 15:e=A.qo(p)
x=e!=null&&C.e.q(e.ghA(),"/api/public/runpod/image/result/")?17:18
break
case 17:x=19
return A.d(B.I8(p),$async$CI)
case 19:case 18:g=p
v=g
x=1
break
case 16:d=B.SR(J.t(r,"output"))
o=d==null?B.SR(r):d
if(o!=null){g=B.L4(o)
throw A.p(g)}x=h?20:21
break
case 20:x=22
return A.d(B.I8(a6),$async$CI)
case 22:v=a6
x=1
break
case 21:g=B.L4(B.cdh(r))
throw A.p(g)
case 14:g=q
if(g==="FAILED"||g==="CANCELLED"){g=A.bz(B.aO3(r))
throw A.p(g)}case 12:u=2
x=9
break
case 7:u=6
a4=t.pop()
g=A.a9(a4)
if(g instanceof B.L3)throw a4
else if(k.b(g)){n=g
m=J.A(n)
if(J.jx(m,"Job failed")||J.jx(m,"AI generation exceeded")||J.jx(m,"Worker returned"))throw a4
a3=n
A.a1J("Polling error (attempt "+A.h(a2)+"): "+A.h(n))}else{l=g
a3=l
g=A.h(a2)
a1=A.h(l)
A.a1J("Polling error (attempt "+g+"): "+a1)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(k.b(a3))throw A.p(a3)
throw A.p(A.bz("Job timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$CI,w)},
I8(d){return B.ctf(d)},
ctf(d){var x=0,w=A.m(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j
var $async$I8=A.n(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:l=null
k=null
q=y.z,p=y.t,o=0
case 3:if(!(o<12)){x=5
break}u=7
x=10
return A.d(A.hd(A.bE(d,0,null),null).cK(C.ff),$async$I8)
case 10:s=f
if(s.b===200){x=1
break}k=s.b
if(!C.f.q(A.a([404,425,429,500,502,503,504],p),s.b)){n=B.L4("Generated image result is unavailable (HTTP "+s.b+").")
throw A.p(n)}u=2
x=9
break
case 7:u=6
j=t.pop()
n=A.a9(j)
if(n instanceof B.L3)throw j
else{r=n
l=r}x=9
break
case 6:x=2
break
case 9:x=11
return A.d(A.iw(D.qI,null,q),$async$I8)
case 11:case 4:++o
x=3
break
case 5:if(k!=null)throw A.p(B.L4("Generated image result is not ready yet (HTTP "+A.h(k)+"). Try again in a moment."))
q=l
throw A.p(B.L4("Generated image result is not ready yet: "+A.h(q==null?"unknown error":q)))
case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$I8,w)},
L3:function L3(d){this.a=d},
aO2:function aO2(){},
lu(d,e,f,g,h,i,j,k,l,m){return new B.Ac(e,f,h,j,k,l,d,i,m,g,null)},
b2N:function b2N(d,e){this.a=d
this.b=e},
Ac:function Ac(d,e,f,g,h,i,j,k,l,m,n){var _=this
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
b2P:function b2P(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0,a1,a2,a3,a4,a5){var _=this
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
b2Q:function b2Q(d){this.a=d}},D,H
J=c[1]
A=c[0]
C=c[2]
G=c[46]
E=c[30]
F=c[42]
B=a.updateHolder(c[19],B)
D=c[54]
H=c[55]
B.L3.prototype={
j(d){return this.a},
$icm:1}
B.b2N.prototype={
O(){return"_ChipVariant."+this.b}}
B.Ac.prototype={
E(d){var x,w,v,u,t,s,r=this,q=null,p=E.c9j(d)
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
return E.a9o(!1,q,C.dZ,q,r.cx,q,q,C.v,q,new B.b2P(d,w,v,D.jB,q,q,q,q,q,q,q,q,q,!0,q,q,q,q,F.kJ,q,q,q,q,q,q,q,q),q,q,q,q,q,q,q,q,w,r.d,q,u,r.dx,q,q,q,x,r.cy,q,v,s,q,q,q,t,r.as,q,!0,q,r.db)}}
B.b2P.prototype={
gic(){var x,w=this,v=w.id
if(v===$){x=A.a5(w.fr)
w.id!==$&&A.aY()
v=w.id=x.ax}return v},
gdn(){if(this.go===D.jB)var x=0
else x=this.fx?1:0
return x},
gyG(){return 1},
gfI(){var x,w,v,u=this,t=u.k1
if(t===$){x=A.a5(u.fr)
u.k1!==$&&A.aY()
t=u.k1=x.ok}x=t.as
if(x==null)x=null
else{if(u.fx)if(u.fy){w=u.gic()
v=w.as
w=v==null?w.z:v}else{w=u.gic()
v=w.rx
w=v==null?w.k3:v}else w=u.gic().k3
w=x.bW(w)
x=w}return x},
gcB(){return new A.ba(new B.b2Q(this),y.b)},
gbJ(){if(this.go===D.jB)var x=C.ap
else{x=this.gic().x1
if(x==null)x=C.U}return x},
gbR(){return C.ap},
gro(){var x,w,v=this
if(v.fx)if(v.fy){x=v.gic()
w=x.as
x=w==null?x.z:w}else x=v.gic().b
else x=v.gic().k3
return x},
grv(){var x,w,v=this
if(v.fx)if(v.fy){x=v.gic()
w=x.as
x=w==null?x.z:w}else{x=v.gic()
w=x.rx
x=w==null?x.k3:w}else x=v.gic().k3
return x},
gee(){var x,w,v=this
if(v.go===D.jB&&!v.fy)if(v.fx){x=v.gic()
w=x.to
if(w==null){w=x.B
x=w==null?x.k3:w}else x=w
x=new A.am(x,1,C.C,-1)}else{x=v.gic().k3
x=new A.am(A.av(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255),1,C.C,-1)}else x=F.ld
return x},
ghd(){var x,w,v=this,u=null
if(v.fx)if(v.fy){x=v.gic()
w=x.as
x=w==null?x.z:w}else x=v.gic().b
else x=v.gic().k3
return new A.eT(18,u,u,u,u,x,u,u,u)},
gci(){return C.cB},
grR(){var x=this.gfI(),w=x==null?null:x.r
if(w==null)w=14
x=A.bT(this.fr,C.bJ)
x=x==null?null:x.gcf()
x=A.pA(C.em,G.eH,A.a1((x==null?C.bo:x).bd(w)/14-1,0,1))
x.toString
return x}}
var z=a.updateTypes([])
B.aO2.prototype={
$1(d){var x
if(y.f.b(d)){x=d.gdr()
x=x.nY(x,12)
return x.aZ(x,", ")}if(y.j.b(d))return"list("+J.az(d)+")"
if(d==null)return"null"
return A.mb(J.ax(d).a,null)},
$S:13}
B.b2Q.prototype={
$1(d){var x,w,v=this
if(d.q(0,C.ao)&&d.q(0,C.ar)){x=v.a
if(x.go===D.jB){x=x.gic().k3
x=A.av(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}else{x=x.gic().k3
x=A.av(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}return x}if(d.q(0,C.ar)){x=v.a
if(x.go===D.jB)x=null
else{x=x.gic().k3
x=A.av(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}return x}if(d.q(0,C.ao)){x=v.a
if(x.go===D.jB){x=x.gic()
w=x.Q
x=w==null?x.y:w}else{x=x.gic()
w=x.Q
x=w==null?x.y:w}return x}x=v.a
if(x.go===D.jB)x=null
else{x=x.gic()
w=x.p3
x=w==null?x.k2:w}return x},
$S:19};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.L3,A.X)
w(A.eB,[B.aO2,B.b2Q])
x(B.b2N,A.j8)
x(B.Ac,A.ao)
x(B.b2P,A.qZ)})()
A.hy(b.typeUniverse,JSON.parse('{"L3":{"cm":[]},"Ac":{"ao":[],"f":[]}}'))
var y=(function rtii(){var x=A.ac
return{L:x("cm"),s:x("B<e>"),t:x("B<u>"),j:x("Y<@>"),P:x("R<e,@>"),f:x("R<@,@>"),N:x("e"),b:x("ba<O?>"),z:x("@"),T:x("e?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.qI=new A.bw(5e6)
D.dQ=new A.ad(0,10,0,10)
D.b7_=x(["image_url","imageUrl","public_url","publicUrl","url","image","output_url","outputUrl","output_image_url","outputImageUrl","result_url","resultUrl","generated_image_url","generatedImageUrl"],y.s)
D.b8f=x(["images","image_urls","imageUrls","artifacts","files","predictions"],y.s)
D.b9l=x(["output","result","data","diagnostics","errors"],y.s)
D.bdu=x(["output","result","data","prediction"],y.s)
D.bel=x(["image_base64","imageBase64","b64_json","base64","image_data","imageData"],y.s)
D.fU=new A.bm(6,null,null,null)
D.jB=new B.b2N(0,"flat")})()};
(a=>{a["aLJK7pz18ALLTvRruM5im00YoDQ="]=a.current})($__dart_deferred_initializers__);