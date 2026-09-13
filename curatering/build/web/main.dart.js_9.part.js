((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={
cbM(d,e){var x,w,v,u,t,s,r,q,p,o,n=new B.ayn(),m=new B.aym(),l=new B.ayl(),k=d.h(0,"positive_prompt")
if(k==null)k=d.h(0,"prompt")
x=C.e.l(A.h(k==null?e:k))
if(x.length===0)throw A.p(A.bA("NLP prompt expansion returned no positive prompt."))
k=d.h(0,"negative_prompt")
k=C.e.l(A.h(k==null?"":k))
w=n.$1(d.h(0,"theme_tokens"))
v=n.$1(d.h(0,"lighting_tokens"))
u=n.$1(d.h(0,"style_tokens"))
t=n.$1(d.h(0,"decor_tokens"))
s=n.$1(d.h(0,"decor_elements"))
r=d.h(0,"visual_keywords")
n=n.$1(r==null?d.h(0,"visual_direction"):r)
r=d.h(0,"recommended_strength")
r=m.$1(r==null?d.h(0,"strength"):r)
m=m.$1(d.h(0,"cfg_scale"))
q=new B.ayk().$1(d.h(0,"steps"))
p=l.$1(d.h(0,"controlnet"))
o=d.h(0,"mode")
o=o==null?null:J.v(o)
return new B.a4U(x,k,w,v,u,t,s,n,r,m,q,p,o,l.$1(d.h(0,"transformation_plan")))},
aOf(d){var x=y.w,w=y.b
return y.B.b(d)?A.az(d,x,w):A.H(x,w)},
ceC(d){var x,w,v=B.aOf(d.h(0,"output")),u=B.aOf(v.h(0,"result"))
if(u.a!==0)return u
x=B.aOf(v.h(0,"analysis"))
if(x.a!==0)return x
if(v.a!==0)return v
w=B.aOf(d.h(0,"result"))
if(w.a!==0)return w
return d},
Sw(d,e){return B.cuY(d,e)},
cuY(d,e){var x=0,w=A.m(y.q),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g
var $async$Sw=A.n(function(f,a0){if(f===1){t.push(a0)
x=u}for(;;)switch(x){case 0:u=4
if(A.xR().length===0)A.aq(A.bA("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
k=y.w
s=A.eA(d,k,y.b)
J.au(s,"task_type","event_prompt_expansion")
r=s
s=A.bz(A.xR()+"/api/public/runpod/nlp/run",0,null)
j=A.N(["Content-Type","application/json"],k,k)
i=y.y
x=7
return A.d(A.es(s,C.a6.cs(A.N(["input",r],k,i),null),null,j).cI(C.qz),$async$Sw)
case 7:q=a0
if(q.b!==200)A.c61(q)
s=q
p=i.a(C.a6.bt(A.cw(A.cv(s.e)).b9(s.w),null))
o=A.aah(J.t(p,"status"))
n=A.ceB(p)
if(o==="COMPLETED"||J.t(p,"output")!=null){s=B.cbM(B.ceC(p),e)
v=s
x=1
break}s=o
if(s==="FAILED"||s==="CANCELLED"){s=A.bA(A.aOe(p))
throw A.p(s)}if(n==null||n.length===0){s=A.bA("NLP prompt expansion did not return a job id.")
throw A.p(s)}x=8
return A.d(B.aai(n),$async$Sw)
case 8:m=a0
s=B.cbM(B.ceC(m),e)
v=s
x=1
break
u=2
x=6
break
case 4:u=3
g=t.pop()
l=A.a7(g)
s=A.bA("Failed to expand event prompt: "+A.h(l))
throw A.p(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$Sw,w)},
aai(d){return B.cuW(d)},
cuW(d){var x=0,w=A.m(y.y),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
var $async$aai=A.n(function(a0,a1){if(a0===1){t.push(a1)
x=u}for(;;)switch(x){case 0:g=0
f=null
m=y.g,l=y.b,k=y.y
case 3:if(!(g<130)){x=4
break}x=5
return A.d(A.h0(C.qB,null,l),$async$aai)
case 5:++g
u=7
x=10
return A.d(A.h8(A.bz(A.xR()+"/api/public/runpod/nlp/status/"+A.f1(2,d,C.bg,!1),0,null),null).cI(C.fn),$async$aai)
case 10:s=a1
if(s.b===429){j=A.bA("Too many requests \u2014 wait a moment and try again.")
throw A.p(j)}if(s.b===200){j=s
r=k.a(C.a6.bt(A.cw(A.cv(j.e)).b9(j.w),null))
q=A.aah(J.t(r,"status"))
if(q==="COMPLETED"){j=r
v=j
x=1
break}j=q
if(j==="FAILED"||j==="CANCELLED"){j=A.bA(A.aOe(r))
throw A.p(j)}}else A.c61(s)
u=2
x=9
break
case 7:u=6
e=t.pop()
j=A.a7(e)
if(m.b(j)){p=j
o=J.v(p)
if(J.jh(o,"Job failed")||J.jh(o,"AI generation exceeded")||J.jh(o,"Worker returned"))throw e
f=p
A.a1u("NLP polling error (attempt "+A.h(g)+"): "+A.h(p))}else{n=j
f=n
j=A.h(g)
h=A.h(n)
A.a1u("NLP polling error (attempt "+j+"): "+h)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(m.b(f))throw A.p(f)
throw A.p(A.bA("NLP task timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$aai,w)},
a4U:function a4U(d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
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
ayn:function ayn(){},
ayo:function ayo(){},
ayp:function ayp(){},
aym:function aym(){},
ayk:function ayk(){},
ayl:function ayl(){}},D
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[16],B)
D=c[40]
B.a4U.prototype={
avw(){var x,w,v=this,u=A.H(y.w,y.b)
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
u.k(0,"nlp_expansion",v.bn())
return u},
bn(){var x,w,v=this,u=A.H(y.w,y.b)
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
B.ayn.prototype={
$1(d){var x
y.d.a(d)
x=d==null?C.bz:d
x=J.c9(x,new B.ayo(),y.w).cF(0,new B.ayp())
x=A.u(x,x.$ti.i("r.E"))
return x},
$S:408}
B.ayo.prototype={
$1(d){return C.e.l(A.h(d))},
$S:14}
B.ayp.prototype={
$1(d){return d.length!==0},
$S:4}
B.aym.prototype={
$1(d){if(typeof d=="number")return d
return A.bC(A.h(d))},
$S:296}
B.ayk.prototype={
$1(d){if(typeof d=="number")return C.i.aK(d)
return A.cd(A.h(d),null)},
$S:1169}
B.ayl.prototype={
$1(d){if(y.B.b(d))return A.az(d,y.w,y.b)
return null},
$S:417};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.a4U,A.a8)
w(A.ht,[B.ayn,B.ayo,B.ayp,B.aym,B.ayk,B.ayl])})()
var y={q:A.ak("a4U"),g:A.ak("cs"),y:A.ak("U<e,@>"),B:A.ak("U<@,@>"),w:A.ak("e"),b:A.ak("@"),d:A.ak("a_<@>?")};(function constants(){D.Ie=new A.al(57531,"MaterialIcons",!1)})()};
(a=>{a["a3hoMMH3NRneS19HPYLbEeityBU="]=a.current})($__dart_deferred_initializers__);