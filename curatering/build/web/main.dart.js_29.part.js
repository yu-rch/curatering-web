((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,F,B={
L6(d){return new B.L5(d)},
yg(){var x=C.e.m("https://curatering.up.railway.app"),w=x.length
if(w===0)return""
return C.e.iI(x,"/")?C.e.ai(x,0,w-1):x},
cej(d){var x,w,v=C.e.m(d)
if(C.e.b8(v,"data:")){x=C.e.dY(v,",")
if(x>=0)v=C.e.bX(v,x+1)}w=A.b7("\\s+",!0,!1,!1)
return A.bP(v,w,"")},
aaj(d){if(d==null)return null
return C.e.m(J.w(d)).toUpperCase()},
aOb(d){var x,w=A.qE(d)
if(w==null||w.gqa()!=="image.runpod.ai"||w.gt3().length<3)return d
if(C.f.ga9(w.gt3())!=="google-nano-banana-2-edit"||C.f.gaU(w.gt3())!=="result.png")return d
x=w.gt3()[1]
return B.yg()+"/api/public/runpod/image/result/"+A.fc(2,x,C.bc,!1)},
cux(d){var x=A.qE(d)
return x!=null&&C.e.q(x.gho(),"/api/public/runpod/image/result/")},
ceg(d){var x,w,v,u=null,t=d.h(0,"id"),s=t==null?u:J.w(t)
if(s!=null&&s.length!==0)return s
t=d.h(0,"jobId")
x=t==null?u:J.w(t)
if(x!=null&&x.length!==0)return x
w=d.h(0,"job")
if(y.f.b(w)){t=w.h(0,"id")
v=t==null?u:J.w(t)
if(v!=null&&v.length!==0)return v}return u},
c5J(d){var x,w,v,u,t,s=d.c,r=s==null?"Request failed":s
try{x=C.a4.bv(A.cI(A.cH(d.e)).bb(d.w),null)
if(y.f.b(x)){if(J.n(x.h(0,"code"),"runpod_not_configured")){v=A.bA("AI generation is not configured on the server. Set RUNPOD_API_KEY and RUNPOD_ENDPOINT_ID on Railway.")
throw A.p(v)}if(x.h(0,"message")!=null)r=A.h(x.h(0,"message"))}}catch(u){w=A.a9(u)
if(y.L.b(w))throw A.p(w)
v=d.e
t=d.w
if(A.cI(A.cH(v)).bb(t).length!==0)r=A.cI(A.cH(v)).bb(t).length>500?C.e.ai(A.cI(A.cH(v)).bb(t),0,500)+"\u2026":A.cI(A.cH(v)).bb(t)}throw A.p(A.bA("HTTP "+d.b+": "+A.h(r)))},
c5I(d,e){var x,w,v=null,u=d==null?v:C.e.m(J.w(d))
if(u==null||u.length===0)return v
if(C.e.b8(u,"http://")||C.e.b8(u,"https://"))return B.aOb(u)
if(C.e.b8(u,"data:image/"))return u
if(!e)return v
x=B.cej(u)
if(x.length<100)return v
w=A.b7("^[A-Za-z0-9+/]+={0,2}$",!0,!1,!1)
if(!w.b.test(x))return v
return"data:image/png;base64,"+x},
CG(d){var x,w,v,u,t,s,r,q=null
if(d==null)return q
if(typeof d=="string")return B.c5I(d,!1)
if(y.j.b(d)){for(x=J.bc(d);x.A();){w=B.CG(x.gR())
if(w!=null)return w}return q}x=y.f
if(!x.b(d))return q
v=A.aB(d,y.N,y.z)
for(u=0;u<14;++u){t=D.b62[u]
s=B.c5I(v.h(0,t),t==="image")
if(s!=null)return s}for(u=0;u<6;++u){s=B.c5I(v.h(0,D.bdl[u]),!0)
if(s!=null)return s}for(u=0;u<6;++u){w=B.CG(v.h(0,D.b7j[u]))
if(w!=null)return w}for(u=0;u<4;++u){w=B.CG(v.h(0,D.bcv[u]))
if(w!=null)return w}r=v.h(0,"diagnostics")
if(x.b(r)){w=B.CG(r)
if(w!=null)return w}return q},
SP(d){var x,w,v,u,t,s,r=null
if(d==null)return r
if(y.j.b(d)){for(x=J.bc(d);x.A();){w=B.SP(x.gR())
if(w!=null)return w}return r}if(!y.f.b(d))return r
v=A.aB(d,y.N,y.z)
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
for(t=0;t<5;++t){s=B.SP(v.h(0,D.b8m[t]))
if(s!=null)return s}return r},
cei(d){var x=B.aaj(d.h(0,"status"))
if(x==null)x="UNKNOWN"
return"AI job completed but returned no image URL. status="+x+", output="+new B.aO8().$1(d.h(0,"output"))},
yh(d,e,f,g,h,i,j){return B.cuC(d,e,f,g,h,i,j)},
cuC(a4,a5,a6,a7,a8,a9,b0){var x=0,w=A.l(y.T),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3
var $async$yh=A.m(function(b1,b2){if(b1===1){t.push(b2)
x=u}for(;;)switch(x){case 0:u=4
if(B.yg().length===0)A.aq(A.bA("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
g=y.N
s=A.I(g,y.z)
J.az(s,"prompt",a4)
J.az(s,"num_inference_steps",a8)
J.e0(s,a5)
r=s
J.az(r,"guidance_scale",a6)
q=b0==null?null:C.e.m(b0)
if(q!=null&&q.length!==0)J.az(r,"user_id",q)
f=C.e.m(a7)
p=f
if(p!=null&&p.length!==0){J.az(r,"init_image_base64",B.cej(p))
J.az(r,"strength",a9)}s=r
e=s.h(0,"task_type")
s=e==null?s.h(0,"task"):e
o=C.e.m(A.h(s==null?"":s)).toLowerCase()==="nano_event_design"
s=A.bG(B.yg()+"/api/public/runpod/run",0,null)
e=A.Q(["Content-Type","application/json"],g,g)
d=y.P
x=7
return A.d(A.eK(s,C.a4.cr(A.Q(["input",r],g,d),null),null,e).cN(C.qB),$async$yh)
case 7:n=b2
x=n.b===200?8:10
break
case 8:s=n
m=d.a(C.a4.bv(A.cI(A.cH(s.e)).bb(s.w),null))
l=B.aaj(J.t(m,"status"))
k=B.ceg(m)
x=l==="COMPLETED"?11:12
break
case 11:a0=B.CG(J.t(m,"output"))
j=a0==null?B.CG(m):a0
x=j!=null?13:14
break
case 13:x=B.cux(j)?15:16
break
case 15:x=17
return A.d(B.I7(j),$async$yh)
case 17:case 16:v=j
x=1
break
case 14:a1=B.SP(J.t(m,"output"))
i=a1==null?B.SP(m):a1
if(i!=null){s=B.L6(i)
throw A.p(s)}x=k!=null&&k.length!==0?18:19
break
case 18:s=o?B.yg()+"/api/public/runpod/image/result/"+A.fc(2,k,C.bc,!1):null
x=20
return A.d(B.CH(k,s),$async$yh)
case 20:s=b2
v=s
x=1
break
case 19:s=B.L6(B.cei(m))
throw A.p(s)
case 12:x=k!=null&&k.length!==0?21:22
break
case 21:s=o?B.yg()+"/api/public/runpod/image/result/"+A.fc(2,k,C.bc,!1):null
x=23
return A.d(B.CH(k,s),$async$yh)
case 23:s=b2
v=s
x=1
break
case 22:s=l
if(s==="FAILED"||s==="CANCELLED"){s=A.bA(B.aO9(m))
throw A.p(s)}s=J.t(m,"error")
if(s==null)s=J.t(m,"message")
s=A.bA("Generation failed: "+A.h(s==null?"No job id from RunPod":s))
throw A.p(s)
x=9
break
case 10:B.c5J(n)
case 9:u=2
x=6
break
case 4:u=3
a3=t.pop()
h=A.a9(a3)
s=A.bA("Failed to generate image: "+A.h(h))
throw A.p(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$yh,w)},
aO9(d){var x=d.h(0,"error"),w=x==null?null:J.w(x)
if(w==null)w="Unknown error"
if(C.e.q(w,"executionTimeout"))return"AI generation exceeded the server time limit (~10 min). Redeploy the RunPod worker image, then try again \u2014 the second attempt is usually faster."
return"Job failed: "+w},
CH(d,e){return B.cuy(d,e)},
cuy(a5,a6){var x=0,w=A.l(y.T),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4
var $async$CH=A.m(function(a7,a8){if(a7===1){t.push(a8)
x=u}for(;;)switch(x){case 0:a2=0
a3=null
k=y.L,j=y.z,i=y.P,h=a6!=null
case 3:if(!(a2<130)){x=4
break}x=5
return A.d(A.hd(D.qD,null,j),$async$CH)
case 5:++a2
u=7
x=10
return A.d(A.hl(A.bG(B.yg()+"/api/public/runpod/status/"+A.fc(2,a5,C.bc,!1),0,null),null).cN(G.fm),$async$CH)
case 10:s=a8
if(s.b===429){g=A.bA("Too many requests \u2014 wait a moment and try again.")
throw A.p(g)}x=s.b===200?11:12
break
case 11:g=s
r=i.a(C.a4.bv(A.cI(A.cH(g.e)).bb(g.w),null))
q=B.aaj(J.t(r,"status"))
x=q==="COMPLETED"?13:14
break
case 13:f=B.CG(J.t(r,"output"))
p=f==null?B.CG(r):f
x=p!=null?15:16
break
case 15:e=A.qE(p)
x=e!=null&&C.e.q(e.gho(),"/api/public/runpod/image/result/")?17:18
break
case 17:x=19
return A.d(B.I7(p),$async$CH)
case 19:case 18:g=p
v=g
x=1
break
case 16:d=B.SP(J.t(r,"output"))
o=d==null?B.SP(r):d
if(o!=null){g=B.L6(o)
throw A.p(g)}x=h?20:21
break
case 20:x=22
return A.d(B.I7(a6),$async$CH)
case 22:v=a6
x=1
break
case 21:g=B.L6(B.cei(r))
throw A.p(g)
case 14:g=q
if(g==="FAILED"||g==="CANCELLED"){g=A.bA(B.aO9(r))
throw A.p(g)}case 12:u=2
x=9
break
case 7:u=6
a4=t.pop()
g=A.a9(a4)
if(g instanceof B.L5)throw a4
else if(k.b(g)){n=g
m=J.w(n)
if(J.jB(m,"Job failed")||J.jB(m,"AI generation exceeded")||J.jB(m,"Worker returned"))throw a4
a3=n
A.a1F("Polling error (attempt "+A.h(a2)+"): "+A.h(n))}else{l=g
a3=l
g=A.h(a2)
a1=A.h(l)
A.a1F("Polling error (attempt "+g+"): "+a1)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(k.b(a3))throw A.p(a3)
throw A.p(A.bA("Job timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$CH,w)},
I7(d){return B.cuA(d)},
cuA(d){var x=0,w=A.l(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j
var $async$I7=A.m(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:l=null
k=null
q=y.z,p=y.t,o=0
case 3:if(!(o<12)){x=5
break}u=7
x=10
return A.d(A.hl(A.bG(d,0,null),null).cN(C.f4),$async$I7)
case 10:s=f
if(s.b===200){x=1
break}k=s.b
if(!C.f.q(A.a([404,425,429,500,502,503,504],p),s.b)){n=B.L6("Generated image result is unavailable (HTTP "+s.b+").")
throw A.p(n)}u=2
x=9
break
case 7:u=6
j=t.pop()
n=A.a9(j)
if(n instanceof B.L5)throw j
else{r=n
l=r}x=9
break
case 6:x=2
break
case 9:x=11
return A.d(A.hd(D.qD,null,q),$async$I7)
case 11:case 4:++o
x=3
break
case 5:if(k!=null)throw A.p(B.L6("Generated image result is not ready yet (HTTP "+A.h(k)+"). Try again in a moment."))
q=l
throw A.p(B.L6("Generated image result is not ready yet: "+A.h(q==null?"unknown error":q)))
case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$I7,w)},
L5:function L5(d){this.a=d},
aO8:function aO8(){},
ky(d,e,f,g,h,i,j,k,l,m){return new B.Ag(e,f,h,j,k,l,d,i,m,g,null)},
b3o:function b3o(d,e){this.a=d
this.b=e},
Ag:function Ag(d,e,f,g,h,i,j,k,l,m,n){var _=this
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
b3q:function b3q(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0,a1,a2,a3,a4,a5){var _=this
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
b3r:function b3r(d){this.a=d}},D,G,E,H,I
J=c[1]
A=c[0]
C=c[2]
F=c[80]
B=a.updateHolder(c[26],B)
D=c[150]
G=c[110]
E=c[60]
H=c[87]
I=c[117]
B.L5.prototype={
j(d){return this.a},
$ics:1}
B.b3o.prototype={
O(){return"_ChipVariant."+this.b}}
B.Ag.prototype={
D(d){var x,w,v,u,t,s,r=this,q=null,p=E.cam(d)
A.a7(d)
x=r.r
w=x!=null
v=r.x
u=r.e
if(u==null)u=v?p.ch:q
t=p.y
if(t==null){A.a7(d)
t=!0}s=r.z
if(s==null)s=p.f
return E.a9k(!1,q,C.dD,q,r.cx,q,q,C.v,q,new B.b3q(d,w,v,D.jC,q,q,q,q,q,q,q,q,q,!0,q,q,q,q,H.kL,q,q,q,q,q,q,q,q),q,q,q,q,q,q,q,q,w,r.d,q,u,r.dx,q,q,q,x,r.cy,q,v,s,q,q,q,t,r.as,q,!0,q,r.db)}}
B.b3q.prototype={
gie(){var x,w=this,v=w.id
if(v===$){x=A.a7(w.fr)
w.id!==$&&A.b_()
v=w.id=x.ax}return v},
gdq(){if(this.go===D.jC)var x=0
else x=this.fx?1:0
return x},
gyS(){return 1},
gfK(){var x,w,v,u=this,t=u.k1
if(t===$){x=A.a7(u.fr)
u.k1!==$&&A.b_()
t=u.k1=x.ok}x=t.as
if(x==null)x=null
else{if(u.fx)if(u.fy){w=u.gie()
v=w.as
w=v==null?w.z:v}else{w=u.gie()
v=w.rx
w=v==null?w.k3:v}else w=u.gie().k3
w=x.bW(w)
x=w}return x},
gcB(){return new A.b8(new B.b3r(this),y.b)},
gbM(){if(this.go===D.jC)var x=C.aq
else{x=this.gie().x1
if(x==null)x=C.T}return x},
gbR(){return C.aq},
grt(){var x,w,v=this
if(v.fx)if(v.fy){x=v.gie()
w=x.as
x=w==null?x.z:w}else x=v.gie().b
else x=v.gie().k3
return x},
grC(){var x,w,v=this
if(v.fx)if(v.fy){x=v.gie()
w=x.as
x=w==null?x.z:w}else{x=v.gie()
w=x.rx
x=w==null?x.k3:w}else x=v.gie().k3
return x},
gec(){var x,w,v=this
if(v.go===D.jC&&!v.fy)if(v.fx){x=v.gie()
w=x.to
if(w==null){w=x.B
x=w==null?x.k3:w}else x=w
x=new A.aj(x,1,C.A,-1)}else{x=v.gie().k3
x=new A.aj(A.ax(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255),1,C.A,-1)}else x=I.ld
return x},
ghh(){var x,w,v=this,u=null
if(v.fx)if(v.fy){x=v.gie()
w=x.as
x=w==null?x.z:w}else x=v.gie().b
else x=v.gie().k3
return new A.eW(18,u,u,u,u,x,u,u,u)},
gci(){return C.cE},
grU(){var x=this.gfK(),w=x==null?null:x.r
if(w==null)w=14
x=A.bU(this.fr,C.bL)
x=x==null?null:x.gcf()
x=A.pL(C.en,F.eJ,A.a4((x==null?C.bp:x).bi(w)/14-1,0,1))
x.toString
return x}}
var z=a.updateTypes([])
B.aO8.prototype={
$1(d){var x
if(y.f.b(d)){x=d.gds()
x=x.o5(x,12)
return x.b0(x,", ")}if(y.j.b(d))return"list("+J.av(d)+")"
if(d==null)return"null"
return A.md(J.ay(d).a,null)},
$S:13}
B.b3r.prototype={
$1(d){var x,w,v=this
if(d.q(0,C.ao)&&d.q(0,C.as)){x=v.a
if(x.go===D.jC){x=x.gie().k3
x=A.ax(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}else{x=x.gie().k3
x=A.ax(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}return x}if(d.q(0,C.as)){x=v.a
if(x.go===D.jC)x=null
else{x=x.gie().k3
x=A.ax(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}return x}if(d.q(0,C.ao)){x=v.a
if(x.go===D.jC){x=x.gie()
w=x.Q
x=w==null?x.y:w}else{x=x.gie()
w=x.Q
x=w==null?x.y:w}return x}x=v.a
if(x.go===D.jC)x=null
else{x=x.gie()
w=x.p3
x=w==null?x.k2:w}return x},
$S:18};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.L5,A.W)
w(A.de,[B.aO8,B.b3r])
x(B.b3o,A.fZ)
x(B.Ag,A.am)
x(B.b3q,A.r9)})()
A.dF(b.typeUniverse,JSON.parse('{"L5":{"cs":[]},"Ag":{"am":[],"f":[]}}'))
var y=(function rtii(){var x=A.Y
return{L:x("cs"),s:x("z<e>"),t:x("z<u>"),j:x("a_<@>"),P:x("S<e,@>"),f:x("S<@,@>"),N:x("e"),b:x("b8<P?>"),z:x("@"),T:x("e?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.qD=new A.by(5e6)
D.b62=x(["image_url","imageUrl","public_url","publicUrl","url","image","output_url","outputUrl","output_image_url","outputImageUrl","result_url","resultUrl","generated_image_url","generatedImageUrl"],y.s)
D.b7j=x(["images","image_urls","imageUrls","artifacts","files","predictions"],y.s)
D.b8m=x(["output","result","data","diagnostics","errors"],y.s)
D.bcv=x(["output","result","data","prediction"],y.s)
D.bdl=x(["image_base64","imageBase64","b64_json","base64","image_data","imageData"],y.s)
D.jC=new B.b3o(0,"flat")})()};
(a=>{a["jsj6Cqakdn6iaFIb538yyp4RI3s="]=a.current})($__dart_deferred_initializers__);