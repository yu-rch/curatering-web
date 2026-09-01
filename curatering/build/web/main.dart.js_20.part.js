((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,G,E,F,B={
LO(d){return new B.LN(d)},
yO(){var x=C.e.n("https://curatering.up.railway.app"),w=x.length
if(w===0)return""
return C.e.iF(x,"/")?C.e.ah(x,0,w-1):x},
cg2(d){var x,w,v=C.e.n(d)
if(C.e.b4(v,"data:")){x=C.e.dB(v,",")
if(x>=0)v=C.e.bR(v,x+1)}w=A.b4("\\s+",!0,!1,!1)
return A.bF(v,w,"")},
abE(d){if(d==null)return null
return C.e.n(J.A(d)).toUpperCase()},
aQC(d){var x,w=A.qX(d)
if(w==null||w.gq4(w)!=="image.runpod.ai"||w.gt1().length<3)return d
if(C.f.ga1(w.gt1())!=="google-nano-banana-2-edit"||C.f.gaH(w.gt1())!=="result.png")return d
x=w.gt1()[1]
return B.yO()+"/api/public/runpod/image/result/"+A.fk(2,x,C.b9,!1)},
cw9(d){var x=A.qX(d)
return x!=null&&C.e.q(x.ghz(x),"/api/public/runpod/image/result/")},
cg_(d){var x,w,v,u=null,t=J.a2(d),s=t.h(d,"id"),r=s==null?u:J.A(s)
if(r!=null&&r.length!==0)return r
s=t.h(d,"jobId")
x=s==null?u:J.A(s)
if(x!=null&&x.length!==0)return x
w=t.h(d,"job")
if(y.f.b(w)){t=J.h(w,"id")
v=t==null?u:J.A(t)
if(v!=null&&v.length!==0)return v}return u},
c7b(d){var x,w,v,u,t,s=d.c,r=s==null?"Request failed":s
try{x=C.a4.bt(0,A.cH(A.cG(d.e)).b7(0,d.w),null)
if(y.f.b(x)){if(J.k(J.h(x,"code"),"runpod_not_configured")){v=A.bG("AI generation is not configured on the server. Set RUNPOD_API_KEY and RUNPOD_ENDPOINT_ID on Railway.")
throw A.j(v)}if(J.h(x,"message")!=null)r=A.i(J.h(x,"message"))}}catch(u){w=A.ab(u)
if(y.L.b(w))throw A.j(w)
v=d.e
t=d.w
if(A.cH(A.cG(v)).b7(0,t).length!==0)r=A.cH(A.cG(v)).b7(0,t).length>500?C.e.ah(A.cH(A.cG(v)).b7(0,t),0,500)+"\u2026":A.cH(A.cG(v)).b7(0,t)}throw A.j(A.bG("HTTP "+d.b+": "+A.i(r)))},
c7a(d,e){var x,w,v=null,u=d==null?v:C.e.n(J.A(d))
if(u==null||u.length===0)return v
if(C.e.b4(u,"http://")||C.e.b4(u,"https://"))return B.aQC(u)
if(C.e.b4(u,"data:image/"))return u
if(!e)return v
x=B.cg2(u)
if(x.length<100)return v
w=A.b4("^[A-Za-z0-9+/]+={0,2}$",!0,!1,!1)
if(!w.b.test(x))return v
return"data:image/png;base64,"+x},
Dl(d){var x,w,v,u,t,s,r,q=null
if(d==null)return q
if(typeof d=="string")return B.c7a(d,!1)
if(y.j.b(d)){for(x=J.aW(d);x.A();){w=B.Dl(x.gR(x))
if(w!=null)return w}return q}x=y.f
if(!x.b(d))return q
v=A.aM(d,y.N,y.z)
for(u=0;u<14;++u){t=D.b72[u]
s=B.c7a(v.h(0,t),t==="image")
if(s!=null)return s}for(u=0;u<6;++u){s=B.c7a(v.h(0,D.beo[u]),!0)
if(s!=null)return s}for(u=0;u<6;++u){w=B.Dl(v.h(0,D.b8i[u]))
if(w!=null)return w}for(u=0;u<4;++u){w=B.Dl(v.h(0,D.bdx[u]))
if(w!=null)return w}r=v.h(0,"diagnostics")
if(x.b(r)){w=B.Dl(r)
if(w!=null)return w}return q},
TG(d){var x,w,v,u,t,s,r=null
if(d==null)return r
if(y.j.b(d)){for(x=J.aW(d);x.A();){w=B.TG(x.gR(x))
if(w!=null)return w}return r}if(!y.f.b(d))return r
v=A.aM(d,y.N,y.z)
x=v.h(0,"status")
if(x==null)x=v.h(0,"state")
u=C.e.n(A.i(x==null?"":x)).toLowerCase()
x=v.h(0,"message")
if(x==null)x=v.h(0,"error")
if(x==null)x=v.h(0,"detail")
w=C.e.n(A.i(x==null?"":x))
if(u==="error"||u==="failed"||u==="cancelled"||u==="canceled")return w.length===0?"Worker returned status "+u+".":w
if(w.length!==0){x=A.b4("error|failed",!1,!1,!1)
x=x.b.test(w)}else x=!1
if(x)return w
for(t=0;t<5;++t){s=B.TG(v.h(0,D.b9o[t]))
if(s!=null)return s}return r},
cg1(d){var x=J.a2(d),w=B.abE(x.h(d,"status"))
if(w==null)w="UNKNOWN"
return"AI job completed but returned no image URL. status="+w+", output="+new B.aQz().$1(x.h(d,"output"))},
yP(d,e,f,g,h,i,j){return B.cwe(d,e,f,g,h,i,j)},
cwe(a4,a5,a6,a7,a8,a9,b0){var x=0,w=A.o(y.T),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3
var $async$yP=A.p(function(b1,b2){if(b1===1){t.push(b2)
x=u}for(;;)switch(x){case 0:u=4
if(B.yO().length===0)A.ao(A.bG("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
g=y.N
s=A.G(g,y.z)
J.aC(s,"prompt",a4)
J.aC(s,"num_inference_steps",a8)
J.eM(s,a5)
r=s
J.aC(r,"guidance_scale",a6)
q=b0==null?null:C.e.n(b0)
if(q!=null&&q.length!==0)J.aC(r,"user_id",q)
f=C.e.n(a7)
p=f
if(p!=null&&p.length!==0){J.aC(r,"init_image_base64",B.cg2(p))
J.aC(r,"strength",a9)}s=r
e=J.a2(s)
d=e.h(s,"task_type")
s=d==null?e.h(s,"task"):d
o=C.e.n(A.i(s==null?"":s)).toLowerCase()==="nano_event_design"
s=A.bM(B.yO()+"/api/public/runpod/run",0,null)
e=A.Q(["Content-Type","application/json"],g,g)
d=y.P
x=7
return A.d(A.eV(s,C.a4.cs(A.Q(["input",r],g,d),null),null,e).cN(0,C.xR),$async$yP)
case 7:n=b2
x=n.b===200?8:10
break
case 8:s=n
m=d.a(C.a4.bt(0,A.cH(A.cG(s.e)).b7(0,s.w),null))
l=B.abE(J.h(m,"status"))
k=B.cg_(m)
x=l==="COMPLETED"?11:12
break
case 11:a0=B.Dl(J.h(m,"output"))
j=a0==null?B.Dl(m):a0
x=j!=null?13:14
break
case 13:x=B.cw9(j)?15:16
break
case 15:x=17
return A.d(B.IS(j),$async$yP)
case 17:case 16:v=j
x=1
break
case 14:a1=B.TG(J.h(m,"output"))
i=a1==null?B.TG(m):a1
if(i!=null){s=B.LO(i)
throw A.j(s)}x=k!=null&&k.length!==0?18:19
break
case 18:s=o?B.yO()+"/api/public/runpod/image/result/"+A.fk(2,k,C.b9,!1):null
x=20
return A.d(B.Dm(k,s),$async$yP)
case 20:s=b2
v=s
x=1
break
case 19:s=B.LO(B.cg1(m))
throw A.j(s)
case 12:x=k!=null&&k.length!==0?21:22
break
case 21:s=o?B.yO()+"/api/public/runpod/image/result/"+A.fk(2,k,C.b9,!1):null
x=23
return A.d(B.Dm(k,s),$async$yP)
case 23:s=b2
v=s
x=1
break
case 22:s=l
if(s==="FAILED"||s==="CANCELLED"){s=A.bG(B.aQA(m))
throw A.j(s)}s=J.h(m,"error")
if(s==null)s=J.h(m,"message")
s=A.bG("Generation failed: "+A.i(s==null?"No job id from RunPod":s))
throw A.j(s)
x=9
break
case 10:B.c7b(n)
case 9:u=2
x=6
break
case 4:u=3
a3=t.pop()
h=A.ab(a3)
s=A.bG("Failed to generate image: "+A.i(h))
throw A.j(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$yP,w)},
aQA(d){var x=J.h(d,"error"),w=x==null?null:J.A(x)
if(w==null)w="Unknown error"
if(C.e.q(w,"executionTimeout"))return"AI generation exceeded the server time limit (~10 min). Redeploy the RunPod worker image, then try again \u2014 the second attempt is usually faster."
return"Job failed: "+w},
Dm(d,e){return B.cwa(d,e)},
cwa(a7,a8){var x=0,w=A.o(y.T),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0,a1,a2,a3,a4,a5,a6
var $async$Dm=A.p(function(a9,b0){if(a9===1){t.push(b0)
x=u}for(;;)switch(x){case 0:a4=0
a5=null
k=y.L,j=y.z,i=y.P,h=a8!=null
case 3:if(!(a4<130)){x=4
break}x=5
return A.d(A.iE(D.qI,null,j),$async$Dm)
case 5:++a4
u=7
x=10
return A.d(A.hq(A.bM(B.yO()+"/api/public/runpod/status/"+A.fk(2,a7,C.b9,!1),0,null),null).cN(0,H.fg),$async$Dm)
case 10:s=b0
if(s.b===429){g=A.bG("Too many requests \u2014 wait a moment and try again.")
throw A.j(g)}x=s.b===200?11:12
break
case 11:g=s
r=i.a(C.a4.bt(0,A.cH(A.cG(g.e)).b7(0,g.w),null))
q=B.abE(J.h(r,"status"))
x=q==="COMPLETED"?13:14
break
case 13:f=B.Dl(J.h(r,"output"))
p=f==null?B.Dl(r):f
x=p!=null?15:16
break
case 15:e=A.qX(p)
if(e!=null){g=e.ghz(e)
g=A.rd(g,"/api/public/runpod/image/result/",0)}else g=!1
x=g?17:18
break
case 17:x=19
return A.d(B.IS(p),$async$Dm)
case 19:case 18:g=p
v=g
x=1
break
case 16:d=B.TG(J.h(r,"output"))
o=d==null?B.TG(r):d
if(o!=null){g=B.LO(o)
throw A.j(g)}x=h?20:21
break
case 20:x=22
return A.d(B.IS(a8),$async$Dm)
case 22:v=a8
x=1
break
case 21:g=B.LO(B.cg1(r))
throw A.j(g)
case 14:g=q
if(g==="FAILED"||g==="CANCELLED"){g=A.bG(B.aQA(r))
throw A.j(g)}case 12:u=2
x=9
break
case 7:u=6
a6=t.pop()
g=A.ab(a6)
if(g instanceof B.LN)throw a6
else if(k.b(g)){n=g
m=J.A(n)
g=m
a1=J.a2(g)
a2=a1.gB(g)
if(0>a2)A.ao(A.ev(0,0,a1.gB(g),null,null))
a1=!0
if(!A.rd(g,"Job failed",0)){g=m
a2=J.a2(g)
a3=a2.gB(g)
if(0>a3)A.ao(A.ev(0,0,a2.gB(g),null,null))
if(!A.rd(g,"AI generation exceeded",0)){g=m
a1=J.a2(g)
a2=a1.gB(g)
if(0>a2)A.ao(A.ev(0,0,a1.gB(g),null,null))
g=A.rd(g,"Worker returned",0)}else g=a1}else g=a1
if(g)throw a6
a5=n
A.a2D("Polling error (attempt "+A.i(a4)+"): "+A.i(n))}else{l=g
a5=l
g=A.i(a4)
a1=A.i(l)
A.a2D("Polling error (attempt "+g+"): "+a1)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(k.b(a5))throw A.j(a5)
throw A.j(A.bG("Job timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$Dm,w)},
IS(d){return B.cwc(d)},
cwc(d){var x=0,w=A.o(y.H),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j
var $async$IS=A.p(function(e,f){if(e===1){t.push(f)
x=u}for(;;)switch(x){case 0:l=null
k=null
q=y.z,p=y.t,o=0
case 3:if(!(o<12)){x=5
break}u=7
x=10
return A.d(A.hq(A.bM(d,0,null),null).cN(0,C.ff),$async$IS)
case 10:s=f
if(s.b===200){x=1
break}k=s.b
if(!C.f.q(A.a([404,425,429,500,502,503,504],p),s.b)){n=B.LO("Generated image result is unavailable (HTTP "+s.b+").")
throw A.j(n)}u=2
x=9
break
case 7:u=6
j=t.pop()
n=A.ab(j)
if(n instanceof B.LN)throw j
else{r=n
l=r}x=9
break
case 6:x=2
break
case 9:x=11
return A.d(A.iE(D.qI,null,q),$async$IS)
case 11:case 4:++o
x=3
break
case 5:if(k!=null)throw A.j(B.LO("Generated image result is not ready yet (HTTP "+A.i(k)+"). Try again in a moment."))
q=l
throw A.j(B.LO("Generated image result is not ready yet: "+A.i(q==null?"unknown error":q)))
case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$IS,w)},
LN:function LN(d){this.a=d},
aQz:function aQz(){},
lI(d,e,f,g,h,i,j,k,l,m){return new B.AP(e,f,h,j,k,l,d,i,m,g,null)},
b5m:function b5m(d,e){this.a=d
this.b=e},
AP:function AP(d,e,f,g,h,i,j,k,l,m,n){var _=this
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
b5n:function b5n(d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,a0,a1,a2,a3,a4,a5){var _=this
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
b5o:function b5o(d){this.a=d}},D,H
J=c[1]
A=c[0]
C=c[2]
G=c[34]
E=c[23]
F=c[31]
B=a.updateHolder(c[16],B)
D=c[37]
H=c[38]
B.LN.prototype={
j(d){return this.a},
$ict:1}
B.b5m.prototype={
O(){return"_ChipVariant."+this.b}}
B.AP.prototype={
F(d){var x,w,v,u,t,s,r=this,q=null,p=E.cc2(d)
A.a6(d)
x=r.r
w=x!=null
v=r.x
u=r.e
if(u==null)u=v?p.ch:q
t=p.y
if(t==null){A.a6(d)
t=!0}s=r.z
if(s==null)s=p.f
return E.aaI(!1,q,C.dZ,q,r.cx,q,q,C.v,q,new B.b5n(d,w,v,D.jC,q,q,q,q,q,q,q,q,q,!0,q,q,q,q,F.kJ,q,q,q,q,q,q,q,q),q,q,q,q,q,q,q,q,w,r.d,q,u,r.dx,q,q,q,x,r.cy,q,v,s,q,q,q,t,r.as,q,!0,q,r.db)}}
B.b5n.prototype={
gie(){var x,w=this,v=w.id
if(v===$){x=A.a6(w.fr)
w.id!==$&&A.b2()
v=w.id=x.ax}return v},
gdn(d){var x
if(this.go===D.jC)x=0
else x=this.fx?1:0
return x},
gyH(){return 1},
gfJ(){var x,w,v,u=this,t=u.k1
if(t===$){x=A.a6(u.fr)
u.k1!==$&&A.b2()
t=u.k1=x.ok}x=t.as
if(x==null)x=null
else{if(u.fx)if(u.fy){w=u.gie()
v=w.as
w=v==null?w.z:v}else{w=u.gie()
v=w.rx
w=v==null?w.k3:v}else w=u.gie().k3
w=x.bX(w)
x=w}return x},
gcC(d){return new A.bh(new B.b5o(this),y.b)},
gbJ(d){var x
if(this.go===D.jC)x=C.ap
else{x=this.gie().x1
if(x==null)x=C.U}return x},
gbS(){return C.ap},
grp(){var x,w,v=this
if(v.fx)if(v.fy){x=v.gie()
w=x.as
x=w==null?x.z:w}else x=v.gie().b
else x=v.gie().k3
return x},
grw(){var x,w,v=this
if(v.fx)if(v.fy){x=v.gie()
w=x.as
x=w==null?x.z:w}else{x=v.gie()
w=x.rx
x=w==null?x.k3:w}else x=v.gie().k3
return x},
gee(){var x,w,v=this
if(v.go===D.jC&&!v.fy)if(v.fx){x=v.gie()
w=x.to
if(w==null){w=x.C
x=w==null?x.k3:w}else x=w
x=new A.ap(x,1,C.C,-1)}else{x=v.gie().k3
x=new A.ap(A.ax(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255),1,C.C,-1)}else x=F.ld
return x},
ghc(){var x,w,v=this,u=null
if(v.fx)if(v.fy){x=v.gie()
w=x.as
x=w==null?x.z:w}else x=v.gie().b
else x=v.gie().k3
return new A.f5(18,u,u,u,u,x,u,u,u)},
gci(d){return C.cB},
grS(){var x=this.gfJ(),w=x==null?null:x.r
if(w==null)w=14
x=A.c_(this.fr,C.bJ)
x=x==null?null:x.gcf()
x=A.q6(C.em,G.eH,A.a3((x==null?C.bo:x).bd(0,w)/14-1,0,1))
x.toString
return x}}
var z=a.updateTypes([])
B.aQz.prototype={
$1(d){var x
if(y.f.b(d)){x=J.MW(J.MU(d),12)
return x.b_(x,", ")}if(y.j.b(d))return"list("+J.aD(d)+")"
if(d==null)return"null"
return A.mx(J.az(d).a,null)},
$S:13}
B.b5o.prototype={
$1(d){var x,w,v=this
if(d.q(0,C.an)&&d.q(0,C.ar)){x=v.a
if(x.go===D.jC){x=x.gie().k3
x=A.ax(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}else{x=x.gie().k3
x=A.ax(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}return x}if(d.q(0,C.ar)){x=v.a
if(x.go===D.jC)x=null
else{x=x.gie().k3
x=A.ax(31,x.u()>>>16&255,x.u()>>>8&255,x.u()&255)}return x}if(d.q(0,C.an)){x=v.a
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
x(B.LN,A.a1)
w(A.fK,[B.aQz,B.b5o])
x(B.b5m,A.lw)
x(B.AP,A.as)
x(B.b5n,A.rw)})()
A.k6(b.typeUniverse,JSON.parse('{"LN":{"ct":[]},"AP":{"as":[],"f":[]}}'))
var y=(function rtii(){var x=A.aj
return{L:x("ct"),s:x("B<e>"),t:x("B<u>"),j:x("S<@>"),P:x("R<e,@>"),f:x("R<@,@>"),N:x("e"),b:x("bh<O?>"),z:x("@"),T:x("e?"),H:x("~")}})();(function constants(){var x=a.makeConstList
D.qI=new A.bC(5e6)
D.dQ=new A.ae(0,10,0,10)
D.b72=x(["image_url","imageUrl","public_url","publicUrl","url","image","output_url","outputUrl","output_image_url","outputImageUrl","result_url","resultUrl","generated_image_url","generatedImageUrl"],y.s)
D.b8i=x(["images","image_urls","imageUrls","artifacts","files","predictions"],y.s)
D.b9o=x(["output","result","data","diagnostics","errors"],y.s)
D.bdx=x(["output","result","data","prediction"],y.s)
D.beo=x(["image_base64","imageBase64","b64_json","base64","image_data","imageData"],y.s)
D.fU=new A.bt(6,null,null,null)
D.jC=new B.b5m(0,"flat")})()};
(a=>{a["IMuBYA0jcNSY1Ma/2yKgIe/rTIY="]=a.current})($__dart_deferred_initializers__);