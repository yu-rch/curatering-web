((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D,E,F,B={
cbs(d,e){var x,w,v,u,t,s,r,q,p,o,n=new B.ayq(),m=new B.ayp(),l=new B.ayo(),k=d.h(0,"positive_prompt")
if(k==null)k=d.h(0,"prompt")
x=C.e.m(A.h(k==null?e:k))
if(x.length===0)throw A.p(A.bA("NLP prompt expansion returned no positive prompt."))
k=d.h(0,"negative_prompt")
k=C.e.m(A.h(k==null?"":k))
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
q=new B.ayn().$1(d.h(0,"steps"))
p=l.$1(d.h(0,"controlnet"))
o=d.h(0,"mode")
o=o==null?null:J.w(o)
return new B.a5_(x,k,w,v,u,t,s,n,r,m,q,p,o,l.$1(d.h(0,"transformation_plan")))},
aOa(d){var x=y.w,w=y.b
return y.B.b(d)?A.aB(d,x,w):A.I(x,w)},
ceh(d){var x,w,v=B.aOa(d.h(0,"output")),u=B.aOa(v.h(0,"result"))
if(u.a!==0)return u
x=B.aOa(v.h(0,"analysis"))
if(x.a!==0)return x
if(v.a!==0)return v
w=B.aOa(d.h(0,"result"))
if(w.a!==0)return w
return d},
SQ(d,e){return B.cuB(d,e)},
cuB(d,e){var x=0,w=A.l(y.q),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g
var $async$SQ=A.m(function(f,a0){if(f===1){t.push(a0)
x=u}for(;;)switch(x){case 0:u=4
if(D.yg().length===0)A.aq(A.bA("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
k=y.w
s=A.eN(d,k,y.b)
J.az(s,"task_type","event_prompt_expansion")
r=s
s=A.bG(D.yg()+"/api/public/runpod/nlp/run",0,null)
j=A.Q(["Content-Type","application/json"],k,k)
i=y.y
x=7
return A.d(A.eK(s,C.a4.cr(A.Q(["input",r],k,i),null),null,j).cN(C.qB),$async$SQ)
case 7:q=a0
if(q.b!==200)D.c5J(q)
s=q
p=i.a(C.a4.bv(A.cI(A.cH(s.e)).bb(s.w),null))
o=D.aaj(J.t(p,"status"))
n=D.ceg(p)
if(o==="COMPLETED"||J.t(p,"output")!=null){s=B.cbs(B.ceh(p),e)
v=s
x=1
break}s=o
if(s==="FAILED"||s==="CANCELLED"){s=A.bA(D.aO9(p))
throw A.p(s)}if(n==null||n.length===0){s=A.bA("NLP prompt expansion did not return a job id.")
throw A.p(s)}x=8
return A.d(B.aak(n),$async$SQ)
case 8:m=a0
s=B.cbs(B.ceh(m),e)
v=s
x=1
break
u=2
x=6
break
case 4:u=3
g=t.pop()
l=A.a9(g)
s=A.bA("Failed to expand event prompt: "+A.h(l))
throw A.p(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$SQ,w)},
aak(d){return B.cuz(d)},
cuz(d){var x=0,w=A.l(y.y),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
var $async$aak=A.m(function(a0,a1){if(a0===1){t.push(a1)
x=u}for(;;)switch(x){case 0:g=0
f=null
m=y.g,l=y.b,k=y.y
case 3:if(!(g<130)){x=4
break}x=5
return A.d(A.hd(E.qD,null,l),$async$aak)
case 5:++g
u=7
x=10
return A.d(A.hl(A.bG(D.yg()+"/api/public/runpod/nlp/status/"+A.fc(2,d,C.bc,!1),0,null),null).cN(F.fm),$async$aak)
case 10:s=a1
if(s.b===429){j=A.bA("Too many requests \u2014 wait a moment and try again.")
throw A.p(j)}if(s.b===200){j=s
r=k.a(C.a4.bv(A.cI(A.cH(j.e)).bb(j.w),null))
q=D.aaj(J.t(r,"status"))
if(q==="COMPLETED"){j=r
v=j
x=1
break}j=q
if(j==="FAILED"||j==="CANCELLED"){j=A.bA(D.aO9(r))
throw A.p(j)}}else D.c5J(s)
u=2
x=9
break
case 7:u=6
e=t.pop()
j=A.a9(e)
if(m.b(j)){p=j
o=J.w(p)
if(J.jB(o,"Job failed")||J.jB(o,"AI generation exceeded")||J.jB(o,"Worker returned"))throw e
f=p
A.a1F("NLP polling error (attempt "+A.h(g)+"): "+A.h(p))}else{n=j
f=n
j=A.h(g)
h=A.h(n)
A.a1F("NLP polling error (attempt "+j+"): "+h)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(m.b(f))throw A.p(f)
throw A.p(A.bA("NLP task timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$aak,w)},
a5_:function a5_(d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
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
ayq:function ayq(){},
ayr:function ayr(){},
ays:function ays(){},
ayp:function ayp(){},
ayn:function ayn(){},
ayo:function ayo(){}},G
J=c[1]
A=c[0]
C=c[2]
D=c[26]
E=c[150]
F=c[110]
B=a.updateHolder(c[16],B)
G=c[123]
B.a5_.prototype={
avu(){var x,w,v=this,u=A.I(y.w,y.b)
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
u.k(0,"nlp_expansion",v.bo())
return u},
bo(){var x,w,v=this,u=A.I(y.w,y.b)
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
B.ayq.prototype={
$1(d){var x
y.d.a(d)
x=d==null?C.bv:d
x=J.cj(x,new B.ayr(),y.w).cH(0,new B.ays())
x=A.v(x,x.$ti.i("r.E"))
return x},
$S:271}
B.ayr.prototype={
$1(d){return C.e.m(A.h(d))},
$S:13}
B.ays.prototype={
$1(d){return d.length!==0},
$S:3}
B.ayp.prototype={
$1(d){if(typeof d=="number")return d
return A.bE(A.h(d))},
$S:303}
B.ayn.prototype={
$1(d){if(typeof d=="number")return C.i.aI(d)
return A.ci(A.h(d),null)},
$S:724}
B.ayo.prototype={
$1(d){if(y.B.b(d))return A.aB(d,y.w,y.b)
return null},
$S:298};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.a5_,A.W)
w(A.de,[B.ayq,B.ayr,B.ays,B.ayp,B.ayn,B.ayo])})()
var y={q:A.Y("a5_"),g:A.Y("cs"),y:A.Y("S<e,@>"),B:A.Y("S<@,@>"),w:A.Y("e"),b:A.Y("@"),d:A.Y("a_<@>?")};(function constants(){G.Ie=new A.an(57531,"MaterialIcons",!1)})()};
(a=>{a["1bEGDWwXyRTYVDsXl65DZZm/+w8="]=a.current})($__dart_deferred_initializers__);