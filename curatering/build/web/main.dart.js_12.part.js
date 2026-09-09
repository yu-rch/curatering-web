((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={
Iu(d){return new B.It(d)},
wJ(){var x=C.e.k("https://curatering.up.railway.app"),w=x.length
if(w===0)return""
return C.e.hx(x,"/")?C.e.aa(x,0,w-1):x},
c7n(d){var x,w,v=C.e.k(d)
if(C.e.aV(v,"data:")){x=C.e.dB(v,",")
if(x>=0)v=C.e.bK(v,x+1)}w=A.aT("\\s+",!0,!1,!1)
return A.ba(v,w,"")},
a6y(d){if(d==null)return null
return C.e.k(J.u(d)).toUpperCase()},
aJf(d){var x,w=A.pn(d)
if(w==null||w.gos()!=="image.runpod.ai"||w.gqu().length<3)return d
if(C.f.ga4(w.gqu())!=="google-nano-banana-2-edit"||C.f.gaK(w.gqu())!=="result.png")return d
x=w.gqu()[1]
return B.wJ()+"/api/public/runpod/image/result/"+A.eN(2,x,C.bb,!1)},
cmD(d){var x=A.pn(d)
return x!=null&&C.e.q(x.gfV(),"/api/public/runpod/image/result/")},
c7k(d){var x,w,v,u=null,t=d.h(0,"id"),s=t==null?u:J.u(t)
if(s!=null&&s.length!==0)return s
t=d.h(0,"jobId")
x=t==null?u:J.u(t)
if(x!=null&&x.length!==0)return x
w=d.h(0,"job")
if(y.f.b(w)){t=w.h(0,"id")
v=t==null?u:J.u(t)
if(v!=null&&v.length!==0)return v}return u},
c_r(d){var x,w,v,u,t,s=d.c,r=s==null?"Request failed":s
try{x=C.a4.bl(A.cr(A.cq(d.e)).bb(d.w),null)
if(y.f.b(x)){if(J.i(x.h(0,"code"),"runpod_not_configured")){v=A.bF("AI generation is not configured on the server. Set RUNPOD_API_KEY and RUNPOD_ENDPOINT_ID on Railway.")
throw A.q(v)}if(x.h(0,"message")!=null)r=A.h(x.h(0,"message"))}}catch(u){w=A.a6(u)
if(y.L.b(w))throw A.q(w)
v=d.e
t=d.w
if(A.cr(A.cq(v)).bb(t).length!==0)r=A.cr(A.cq(v)).bb(t).length>500?C.e.aa(A.cr(A.cq(v)).bb(t),0,500)+"\u2026":A.cr(A.cq(v)).bb(t)}throw A.q(A.bF("HTTP "+d.b+": "+A.h(r)))},
c_q(d,e){var x,w,v=null,u=d==null?v:C.e.k(J.u(d))
if(u==null||u.length===0)return v
if(C.e.aV(u,"http://")||C.e.aV(u,"https://"))return B.aJf(u)
if(C.e.aV(u,"data:image/"))return u
if(!e)return v
x=B.c7n(u)
if(x.length<100)return v
w=A.aT("^[A-Za-z0-9+/]+={0,2}$",!0,!1,!1)
if(!w.b.test(x))return v
return"data:image/png;base64,"+x},
AL(d){var x,w,v,u,t,s,r,q=null
if(d==null)return q
if(typeof d=="string")return B.c_q(d,!1)
if(y.j.b(d)){for(x=J.b6(d);x.A();){w=B.AL(x.gT())
if(w!=null)return w}return q}x=y.f
if(!x.b(d))return q
v=A.aH(d,y.N,y.z)
for(u=0;u<14;++u){t=D.b1M[u]
s=B.c_q(v.h(0,t),t==="image")
if(s!=null)return s}for(u=0;u<6;++u){s=B.c_q(v.h(0,D.b5f[u]),!0)
if(s!=null)return s}for(u=0;u<6;++u){w=B.AL(v.h(0,D.b2m[u]))
if(w!=null)return w}for(u=0;u<4;++u){w=B.AL(v.h(0,D.b4T[u]))
if(w!=null)return w}r=v.h(0,"diagnostics")
if(x.b(r)){w=B.AL(r)
if(w!=null)return w}return q},
PZ(d){var x,w,v,u,t,s,r=null
if(d==null)return r
if(y.j.b(d)){for(x=J.b6(d);x.A();){w=B.PZ(x.gT())
if(w!=null)return w}return r}if(!y.f.b(d))return r
v=A.aH(d,y.N,y.z)
x=v.h(0,"status")
if(x==null)x=v.h(0,"state")
u=C.e.k(A.h(x==null?"":x)).toLowerCase()
x=v.h(0,"message")
if(x==null)x=v.h(0,"error")
if(x==null)x=v.h(0,"detail")
w=C.e.k(A.h(x==null?"":x))
if(u==="error"||u==="failed"||u==="cancelled"||u==="canceled")return w.length===0?"Worker returned status "+u+".":w
if(w.length!==0){x=A.aT("error|failed",!1,!1,!1)
x=x.b.test(w)}else x=!1
if(x)return w
for(t=0;t<5;++t){s=B.PZ(v.h(0,D.b2Q[t]))
if(s!=null)return s}return r},
c7m(d){var x=B.a6y(d.h(0,"status"))
if(x==null)x="UNKNOWN"
return"AI job completed but returned no image URL. status="+x+", output="+new B.aJc().$1(d.h(0,"output"))},
wK(d,e,f,g,h,i,j){return B.cmI(d,e,f,g,h,i,j)},
cmI(a4,a5,a6,a7,a8,a9,b0){var x=0,w=A.m(y.T),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3
var $async$wK=A.n(function(b1,b2){if(b1===1){t.push(b2)
x=u}for(;;)switch(x){case 0:u=4
if(B.wJ().length===0)A.ap(A.bF("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
g=y.N
s=A.H(g,y.z)
J.bh(s,"prompt",a4)
J.bh(s,"num_inference_steps",a8)
J.dW(s,a5)
r=s
J.bh(r,"guidance_scale",a6)
q=b0==null?null:C.e.k(b0)
if(q!=null&&q.length!==0)J.bh(r,"user_id",q)
f=C.e.k(a7)
p=f
if(p!=null&&p.length!==0){J.bh(r,"init_image_base64",B.c7n(p))
J.bh(r,"strength",a9)}s=r
e=s.h(0,"task_type")
s=e==null?s.h(0,"task"):e
o=C.e.k(A.h(s==null?"":s)).toLowerCase()==="nano_event_design"
s=A.by(B.wJ()+"/api/public/runpod/run",0,null)
e=A.M(["Content-Type","application/json"],g,g)
d=y.P
x=7
return A.d(A.ek(s,C.a4.ca(A.M(["input",r],g,d),null),null,e).cr(C.pU),$async$wK)
case 7:n=b2
x=n.b===200?8:10
break
case 8:s=n
m=d.a(C.a4.bl(A.cr(A.cq(s.e)).bb(s.w),null))
l=B.a6y(J.a8(m,"status"))
k=B.c7k(m)
x=l==="COMPLETED"?11:12
break
case 11:a0=B.AL(J.a8(m,"output"))
j=a0==null?B.AL(m):a0
x=j!=null?13:14
break
case 13:x=B.cmD(j)?15:16
break
case 15:x=17
return A.d(B.Fz(j),$async$wK)
case 17:case 16:v=j
x=1
break
case 14:a1=B.PZ(J.a8(m,"output"))
i=a1==null?B.PZ(m):a1
if(i!=null){s=B.Iu(i)
throw A.q(s)}x=k!=null&&k.length!==0?18:19
break
case 18:s=o?B.wJ()+"/api/public/runpod/image/result/"+A.eN(2,k,C.bb,!1):null
x=20
return A.d(B.AM(k,s),$async$wK)
case 20:s=b2
v=s
x=1
break
case 19:s=B.Iu(B.c7m(m))
throw A.q(s)
case 12:x=k!=null&&k.length!==0?21:22
break
case 21:s=o?B.wJ()+"/api/public/runpod/image/result/"+A.eN(2,k,C.bb,!1):null
x=23
return A.d(B.AM(k,s),$async$wK)
case 23:s=b2
v=s
x=1
break
case 22:s=l
if(s==="FAILED"||s==="CANCELLED"){s=A.bF(B.aJd(m))
throw A.q(s)}s=J.a8(m,"error")
if(s==null)s=J.a8(m,"message")
s=A.bF("Generation failed: "+A.h(s==null?"No job id from RunPod":s))
throw A.q(s)
x=9
break
case 10:B.c_r(n)
case 9:u=2
x=6
break
case 4:u=3
a3=t.pop()
h=A.a6(a3)
s=A.bF("Failed to generate image: "+A.h(h))
throw A.q(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$wK,w)},
aJd(d){var x=d.h(0,"error"),w=x==null?null:J.u(x)
if(w==null)w="Unknown error"
if(C.e.q(w,"executionTimeout"))return"AI generation exceeded the server time limit (~10 min). Redeploy the RunPod worker image, then try again \u2014 the second attempt is usually faster."
return"Job failed: "+w},
AM(d,e){return B.cmE(d,e)},
cmE(a5,a6){var x=0,w=A.m(y.T),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$AM=A.n(function(a7,a8){if(a7===1){t.push(a8)
x=u}for(;;)switch(x){case 0:a2=0
a3=null
k=y.L,j=y.z,i=y.P,h=a6!=null
case 3:if(!(a2<130)){x=4
break}x=5
return A.d(A.h4(D.pV,null,j),$async$AM)
case 5:++a2
u=7
x=10
return A.d(A.fJ(A.by(B.wJ()+"/api/public/runpod/status/"+A.eN(2,a5,C.bb,!1),0,null),null).cr(E.f3),$async$AM)
case 10:s=a8
if(s.b===429){g=A.bF("Too many requests \u2014 wait a moment and try again.")
throw A.q(g)}x=s.b===200?11:12
break
case 11:g=s
r=i.a(C.a4.bl(A.cr(A.cq(g.e)).bb(g.w),null))
q=B.a6y(J.a8(r,"status"))
x=q==="COMPLETED"?13:14
break
case 13:f=B.AL(J.a8(r,"output"))
p=f==null?B.AL(r):f
x=p!=null?15:16
break
case 15:e=A.pn(p)
x=e!=null&&C.e.q(e.gfV(),"/api/public/runpod/image/result/")?17:18
break
case 17:x=19
return A.d(B.Fz(p),$async$AM)
case 19:case 18:g=p
v=g
x=1
break
case 16:d=B.PZ(J.a8(r,"output"))
o=d==null?B.PZ(r):d
if(o!=null){g=B.Iu(o)
throw A.q(g)}x=h?20:21
break
case 20:x=22
return A.d(B.Fz(a6),$async$AM)
case 22:v=a6
x=1
break
case 21:g=B.Iu(B.c7m(r))
throw A.q(g)
case 14:g=q
if(g==="FAILED"||g==="CANCELLED"){g=A.bF(B.aJd(r))
throw A.q(g)}case 12:u=2
x=9
break
case 7:u=6
a4=t.pop()
g=A.a6(a4)
if(g instanceof B.It)throw a4
else if(k.b(g)){n=g
m=J.u(n)
if(J.iv(m,"Job failed")||J.iv(m,"AI generation exceeded")||J.iv(m,"Worker returned"))throw a4
a3=n
A.ZM("Polling error (attempt "+A.h(a2)+"): "+A.h(n))}else{l=g
a3=l
g=A.h(a2)
a1=A.h(l)
A.ZM("Polling error (attempt "+g+"): "+a1)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(k.b(a3))throw A.q(a3)
throw A.q(A.bF("Job timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$AM,w)},
Fz(d){return B.cmG(d)},
cmG(d){var x=0,w=A.m(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j
var $async$Fz=A.n(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:l=null
k=null
q=y.z,p=y.t,o=0
case 3:if(!(o<12)){x=5
break}u=7
x=10
return A.d(A.fJ(A.by(d,0,null),null).cr(C.eP),$async$Fz)
case 10:s=f
if(s.b===200){x=1
break}k=s.b
if(!C.f.q(A.a([404,425,429,500,502,503,504],p),s.b)){n=B.Iu("Generated image result is unavailable (HTTP "+s.b+").")
throw A.q(n)}u=2
x=9
break
case 7:u=6
j=t.pop()
n=A.a6(j)
if(n instanceof B.It)throw j
else{r=n
l=r}x=9
break
case 6:x=2
break
case 9:x=11
return A.d(A.h4(D.pV,null,q),$async$Fz)
case 11:case 4:++o
x=3
break
case 5:if(k!=null)throw A.q(B.Iu("Generated image result is not ready yet (HTTP "+A.h(k)+"). Try again in a moment."))
q=l
throw A.q(B.Iu("Generated image result is not ready yet: "+A.h(q==null?"unknown error":q)))
case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$Fz,w)},
It:function It(d){this.a=d},
aJc:function aJc(){},
jR(d,e,f,g,h,i,j,k,l,m){return new B.yD(e,f,h,j,k,l,d,i,m,g,null)},
aYJ:function aYJ(d,e){this.a=d
this.b=e},
yD:function yD(d,e,f,g,h,i,j,k,l,m,n){var _=this
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
aYK:function aYK(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0,a1,a2,a3,a4,a5){var _=this
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
aYL:function aYL(d){this.a=d}},D,E
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[20],B)
D=c[27]
E=c[28]
B.It.prototype={
j(d){return this.a},
$icl:1}
B.aYJ.prototype={
O(){return"_ChipVariant."+this.b}}
B.yD.prototype={
C(d){var x,w,v,u,t,s,r=this,q=null,p=A.c3V(d)
A.a_(d)
x=r.r
w=x!=null
v=r.x
u=r.e
if(u==null)u=v?p.ch:q
t=p.y
if(t==null){A.a_(d)
t=!0}s=r.z
if(s==null)s=p.f
return A.a5x(!1,q,C.dr,q,r.cx,q,q,C.u,q,new B.aYK(d,w,v,D.jb,q,q,q,q,q,q,q,q,q,!0,q,q,q,q,C.kf,q,q,q,q,q,q,q,q),q,q,q,q,q,q,q,q,w,r.d,q,u,r.dx,q,q,q,x,r.cy,q,v,s,q,q,q,t,r.as,q,!0,q,r.db)}}
B.aYK.prototype={
gho(){var x,w=this,v=w.id
if(v===$){x=A.a_(w.fr)
w.id!==$&&A.aW()
v=w.id=x.ax}return v},
gd4(){if(this.go===D.jb)var x=0
else x=this.fx?1:0
return x},
gx3(){return 1},
gf5(){var x,w,v,u=this,t=u.k1
if(t===$){x=A.a_(u.fr)
u.k1!==$&&A.aW()
t=u.k1=x.ok}x=t.as
if(x==null)x=null
else{if(u.fx)if(u.fy){w=u.gho()
v=w.as
w=v==null?w.z:v}else{w=u.gho()
v=w.rx
w=v==null?w.k3:v}else w=u.gho().k3
w=x.bM(w)
x=w}return x},
gcg(){return new A.bc(new B.aYL(this),y.b)},
gbz(){if(this.go===D.jb)var x=C.ao
else{x=this.gho().x1
if(x==null)x=C.T}return x},
gbG(){return C.ao},
gpQ(){var x,w,v=this
if(v.fx)if(v.fy){x=v.gho()
w=x.as
x=w==null?x.z:w}else x=v.gho().b
else x=v.gho().k3
return x},
gpX(){var x,w,v=this
if(v.fx)if(v.fy){x=v.gho()
w=x.as
x=w==null?x.z:w}else{x=v.gho()
w=x.rx
x=w==null?x.k3:w}else x=v.gho().k3
return x},
gdK(){var x,w,v=this
if(v.go===D.jb&&!v.fy)if(v.fx){x=v.gho()
w=x.to
if(w==null){w=x.B
x=w==null?x.k3:w}else x=w
x=new A.ak(x,1,C.C,-1)}else{x=v.gho().k3
x=new A.ak(A.as(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255),1,C.C,-1)}else x=C.kH
return x},
gfC(){var x,w,v=this,u=null
if(v.fx)if(v.fy){x=v.gho()
w=x.as
x=w==null?x.z:w}else x=v.gho().b
else x=v.gho().k3
return new A.ey(18,u,u,u,u,x,u,u,u)},
gc2(){return C.cu},
gqk(){var x=this.gf5(),w=x==null?null:x.r
if(w==null)w=14
x=A.bO(this.fr,C.bG)
x=x==null?null:x.gc1()
x=A.oE(C.eb,C.ew,A.Y((x==null?C.bn:x).b6(w)/14-1,0,1))
x.toString
return x}}
var z=a.updateTypes([])
B.aJc.prototype={
$1(d){var x
if(y.f.b(d)){x=d.gd7()
x=x.mJ(x,12)
return x.aO(x,", ")}if(y.j.b(d))return"list("+J.ay(d)+")"
if(d==null)return"null"
return A.lj(J.au(d).a,null)},
$S:14}
B.aYL.prototype={
$1(d){var x,w,v=this
if(d.q(0,C.am)&&d.q(0,C.ap)){x=v.a
if(x.go===D.jb){x=x.gho().k3
x=A.as(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}else{x=x.gho().k3
x=A.as(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}return x}if(d.q(0,C.ap)){x=v.a
if(x.go===D.jb)x=null
else{x=x.gho().k3
x=A.as(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}return x}if(d.q(0,C.am)){x=v.a
if(x.go===D.jb){x=x.gho()
w=x.Q
x=w==null?x.y:w}else{x=x.gho()
w=x.Q
x=w==null?x.y:w}return x}x=v.a
if(x.go===D.jb)x=null
else{x=x.gho()
w=x.p3
x=w==null?x.k2:w}return x},
$S:20};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.It,A.Z)
w(A.i6,[B.aJc,B.aYL])
x(B.aYJ,A.o4)
x(B.yD,A.ao)
x(B.aYK,A.rH)})()
A.n0(b.typeUniverse,JSON.parse('{"It":{"cl":[]},"yD":{"ao":[],"f":[]}}'))
var y=(function rtii(){var x=A.an
return{L:x("cl"),s:x("E<e>"),t:x("E<w>"),j:x("a2<@>"),P:x("R<e,@>"),f:x("R<@,@>"),N:x("e"),b:x("bc<N?>"),z:x("@"),T:x("e?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.pV=new A.bC(5e6)
D.dS=new A.ab(0,10,0,10)
D.b1M=x(["image_url","imageUrl","public_url","publicUrl","url","image","output_url","outputUrl","output_image_url","outputImageUrl","result_url","resultUrl","generated_image_url","generatedImageUrl"],y.s)
D.b2m=x(["images","image_urls","imageUrls","artifacts","files","predictions"],y.s)
D.b2Q=x(["output","result","data","diagnostics","errors"],y.s)
D.b4T=x(["output","result","data","prediction"],y.s)
D.b5f=x(["image_base64","imageBase64","b64_json","base64","image_data","imageData"],y.s)
D.fD=new A.bl(6,null,null,null)
D.jb=new B.aYJ(0,"flat")})()};
(a=>{a["Hw8CJXfuOfrmPyd3rndEUOa+tso="]=a.current})($__dart_deferred_initializers__);