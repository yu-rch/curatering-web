((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D,E,F,B={
cd7(d,e){var x,w,v,u,t,s,r,q,p,o,n=new B.aAV(),m=new B.aAU(),l=new B.aAT(),k=J.a2(d),j=k.h(d,"positive_prompt")
if(j==null)j=k.h(d,"prompt")
x=C.e.n(A.i(j==null?e:j))
if(x.length===0)throw A.j(A.bG("NLP prompt expansion returned no positive prompt."))
j=k.h(d,"negative_prompt")
j=C.e.n(A.i(j==null?"":j))
w=n.$1(k.h(d,"theme_tokens"))
v=n.$1(k.h(d,"lighting_tokens"))
u=n.$1(k.h(d,"style_tokens"))
t=n.$1(k.h(d,"decor_tokens"))
s=n.$1(k.h(d,"decor_elements"))
r=k.h(d,"visual_keywords")
n=n.$1(r==null?k.h(d,"visual_direction"):r)
r=k.h(d,"recommended_strength")
r=m.$1(r==null?k.h(d,"strength"):r)
m=m.$1(k.h(d,"cfg_scale"))
q=new B.aAS().$1(k.h(d,"steps"))
p=l.$1(k.h(d,"controlnet"))
o=k.h(d,"mode")
o=o==null?null:J.A(o)
return new B.a66(x,j,w,v,u,t,s,n,r,m,q,p,o,l.$1(k.h(d,"transformation_plan")))},
aQB(d){var x=y.w,w=y.b
return y.B.b(d)?A.aM(d,x,w):A.G(x,w)},
cg0(d){var x,w,v=J.a2(d),u=B.aQB(v.h(d,"output")),t=B.aQB(u.h(0,"result"))
if(t.a!==0)return t
x=B.aQB(u.h(0,"analysis"))
if(x.a!==0)return x
if(u.a!==0)return u
w=B.aQB(v.h(d,"result"))
if(w.a!==0)return w
return d},
TH(d,e){return B.cwd(d,e)},
cwd(d,e){var x=0,w=A.o(y.q),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g
var $async$TH=A.p(function(f,a0){if(f===1){t.push(a0)
x=u}for(;;)switch(x){case 0:u=4
if(D.yO().length===0)A.ao(A.bG("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
k=y.w
s=A.fF(d,k,y.b)
J.aC(s,"task_type","event_prompt_expansion")
r=s
s=A.bM(D.yO()+"/api/public/runpod/nlp/run",0,null)
j=A.Q(["Content-Type","application/json"],k,k)
i=y.y
x=7
return A.d(A.eV(s,C.a4.cs(A.Q(["input",r],k,i),null),null,j).cN(0,C.xR),$async$TH)
case 7:q=a0
if(q.b!==200)D.c7b(q)
s=q
p=i.a(C.a4.bt(0,A.cH(A.cG(s.e)).b7(0,s.w),null))
o=D.abE(J.h(p,"status"))
n=D.cg_(p)
if(o==="COMPLETED"||J.h(p,"output")!=null){s=B.cd7(B.cg0(p),e)
v=s
x=1
break}s=o
if(s==="FAILED"||s==="CANCELLED"){s=A.bG(D.aQA(p))
throw A.j(s)}if(n==null||n.length===0){s=A.bG("NLP prompt expansion did not return a job id.")
throw A.j(s)}x=8
return A.d(B.abF(n),$async$TH)
case 8:m=a0
s=B.cd7(B.cg0(m),e)
v=s
x=1
break
u=2
x=6
break
case 4:u=3
g=t.pop()
l=A.ab(g)
s=A.bG("Failed to expand event prompt: "+A.i(l))
throw A.j(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$TH,w)},
abF(d){return B.cwb(d)},
cwb(a1){var x=0,w=A.o(y.y),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,a0
var $async$abF=A.p(function(a2,a3){if(a2===1){t.push(a3)
x=u}for(;;)switch(x){case 0:e=0
d=null
m=y.g,l=y.b,k=y.y
case 3:if(!(e<130)){x=4
break}x=5
return A.d(A.iE(E.qI,null,l),$async$abF)
case 5:++e
u=7
x=10
return A.d(A.hq(A.bM(D.yO()+"/api/public/runpod/nlp/status/"+A.fk(2,a1,C.b9,!1),0,null),null).cN(0,F.fg),$async$abF)
case 10:s=a3
if(s.b===429){j=A.bG("Too many requests \u2014 wait a moment and try again.")
throw A.j(j)}if(s.b===200){j=s
r=k.a(C.a4.bt(0,A.cH(A.cG(j.e)).b7(0,j.w),null))
q=D.abE(J.h(r,"status"))
if(q==="COMPLETED"){j=r
v=j
x=1
break}j=q
if(j==="FAILED"||j==="CANCELLED"){j=A.bG(D.aQA(r))
throw A.j(j)}}else D.c7b(s)
u=2
x=9
break
case 7:u=6
a0=t.pop()
j=A.ab(a0)
if(m.b(j)){p=j
o=J.A(p)
j=o
h=J.a2(j)
g=h.gB(j)
if(0>g)A.ao(A.ev(0,0,h.gB(j),null,null))
h=!0
if(!A.rd(j,"Job failed",0)){j=o
g=J.a2(j)
f=g.gB(j)
if(0>f)A.ao(A.ev(0,0,g.gB(j),null,null))
if(!A.rd(j,"AI generation exceeded",0)){j=o
h=J.a2(j)
g=h.gB(j)
if(0>g)A.ao(A.ev(0,0,h.gB(j),null,null))
j=A.rd(j,"Worker returned",0)}else j=h}else j=h
if(j)throw a0
d=p
A.a2D("NLP polling error (attempt "+A.i(e)+"): "+A.i(p))}else{n=j
d=n
j=A.i(e)
h=A.i(n)
A.a2D("NLP polling error (attempt "+j+"): "+h)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(m.b(d))throw A.j(d)
throw A.j(A.bG("NLP task timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.m(v,w)
case 2:return A.l(t.at(-1),w)}})
return A.n($async$abF,w)},
a66:function a66(d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
_.a=d
_.b=e
_.c=f
_.d=g
_.e=h
_.f=i
_.r=j
_.w=k
_.x=l
_.y=m
_.z=n
_.Q=o
_.as=p
_.at=q},
aAV:function aAV(){},
aAW:function aAW(){},
aAX:function aAX(){},
aAU:function aAU(){},
aAS:function aAS(){},
aAT:function aAT(){}},G
J=c[1]
A=c[0]
C=c[2]
D=c[16]
E=c[37]
F=c[38]
B=a.updateHolder(c[12],B)
G=c[41]
B.a66.prototype={
auY(){var x,w,v=this,u=A.G(y.w,y.b)
u.k(0,"positive_prompt",v.a)
x=v.b
if(x.length!==0)u.k(0,"negative_prompt",x)
u.k(0,"theme_tokens",v.c)
u.k(0,"lighting_tokens",v.d)
u.k(0,"style_tokens",v.e)
u.k(0,"decor_tokens",v.f)
u.k(0,"decor_elements",v.r)
u.k(0,"visual_keywords",v.w)
x=v.x
w=x!=null
if(w)u.k(0,"recommended_strength",x)
if(w)u.k(0,"strength",x)
x=v.y
if(x!=null)u.k(0,"cfg_scale",x)
x=v.z
if(x!=null)u.k(0,"steps",x)
x=v.Q
if(x!=null)u.k(0,"controlnet",x)
x=v.as
if(x!=null&&x.length!==0)u.k(0,"mode",x)
x=v.at
if(x!=null)u.k(0,"transformation_plan",x)
u.k(0,"nlp_expansion",v.bm())
return u},
bm(){var x,w,v=this,u=A.G(y.w,y.b)
u.k(0,"positive_prompt",v.a)
u.k(0,"negative_prompt",v.b)
u.k(0,"theme_tokens",v.c)
u.k(0,"lighting_tokens",v.d)
u.k(0,"style_tokens",v.e)
u.k(0,"decor_tokens",v.f)
u.k(0,"decor_elements",v.r)
u.k(0,"visual_keywords",v.w)
x=v.x
w=x!=null
if(w)u.k(0,"recommended_strength",x)
if(w)u.k(0,"strength",x)
x=v.y
if(x!=null)u.k(0,"cfg_scale",x)
x=v.z
if(x!=null)u.k(0,"steps",x)
x=v.Q
if(x!=null)u.k(0,"controlnet",x)
x=v.as
if(x!=null&&x.length!==0)u.k(0,"mode",x)
x=v.at
if(x!=null)u.k(0,"transformation_plan",x)
return u}}
var z=a.updateTypes([])
B.aAV.prototype={
$1(d){var x
y.d.a(d)
x=d==null?C.by:d
x=J.cr(x,new B.aAW(),y.w).d5(0,new B.aAX())
x=A.v(x,x.$ti.i("r.E"))
return x},
$S:249}
B.aAW.prototype={
$1(d){return C.e.n(A.i(d))},
$S:13}
B.aAX.prototype={
$1(d){return d.length!==0},
$S:4}
B.aAU.prototype={
$1(d){if(typeof d=="number")return d
return A.bI(A.i(d))},
$S:245}
B.aAS.prototype={
$1(d){if(typeof d=="number")return C.i.aI(d)
return A.cF(A.i(d),null)},
$S:772}
B.aAT.prototype={
$1(d){if(y.B.b(d))return A.aM(d,y.w,y.b)
return null},
$S:313};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.a66,A.a1)
w(A.fK,[B.aAV,B.aAW,B.aAX,B.aAU,B.aAS,B.aAT])})()
var y={q:A.aj("a66"),g:A.aj("ct"),y:A.aj("R<e,@>"),B:A.aj("R<@,@>"),w:A.aj("e"),b:A.aj("@"),d:A.aj("S<@>?")};(function constants(){G.Iz=new A.an(57531,"MaterialIcons",!1)})()};
(a=>{a["zXxgB11KUE0ixakXjv4YLMYCWpU="]=a.current})($__dart_deferred_initializers__);