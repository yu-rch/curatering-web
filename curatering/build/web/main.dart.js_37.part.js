((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D,E,F,B={
cbw(d,e){var x,w,v,u,t,s,r,q,p,o,n=new B.ayt(),m=new B.ays(),l=new B.ayr(),k=d.h(0,"positive_prompt")
if(k==null)k=d.h(0,"prompt")
x=C.e.l(A.h(k==null?e:k))
if(x.length===0)throw A.p(A.bB("NLP prompt expansion returned no positive prompt."))
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
q=new B.ayq().$1(d.h(0,"steps"))
p=l.$1(d.h(0,"controlnet"))
o=d.h(0,"mode")
o=o==null?null:J.w(o)
return new B.a5_(x,k,w,v,u,t,s,n,r,m,q,p,o,l.$1(d.h(0,"transformation_plan")))},
aOf(d){var x=y.w,w=y.b
return y.B.b(d)?A.aB(d,x,w):A.I(x,w)},
cel(d){var x,w,v=B.aOf(d.h(0,"output")),u=B.aOf(v.h(0,"result"))
if(u.a!==0)return u
x=B.aOf(v.h(0,"analysis"))
if(x.a!==0)return x
if(v.a!==0)return v
w=B.aOf(d.h(0,"result"))
if(w.a!==0)return w
return d},
SR(d,e){return B.cuI(d,e)},
cuI(d,e){var x=0,w=A.l(y.q),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g
var $async$SR=A.m(function(f,a0){if(f===1){t.push(a0)
x=u}for(;;)switch(x){case 0:u=4
if(D.yh().length===0)A.aq(A.bB("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
k=y.w
s=A.eO(d,k,y.b)
J.ay(s,"task_type","event_prompt_expansion")
r=s
s=A.bG(D.yh()+"/api/public/runpod/nlp/run",0,null)
j=A.Q(["Content-Type","application/json"],k,k)
i=y.y
x=7
return A.d(A.eK(s,C.a4.cr(A.Q(["input",r],k,i),null),null,j).cN(C.qC),$async$SR)
case 7:q=a0
if(q.b!==200)D.c5N(q)
s=q
p=i.a(C.a4.bv(A.cI(A.cH(s.e)).bb(s.w),null))
o=D.aak(J.t(p,"status"))
n=D.cek(p)
if(o==="COMPLETED"||J.t(p,"output")!=null){s=B.cbw(B.cel(p),e)
v=s
x=1
break}s=o
if(s==="FAILED"||s==="CANCELLED"){s=A.bB(D.aOe(p))
throw A.p(s)}if(n==null||n.length===0){s=A.bB("NLP prompt expansion did not return a job id.")
throw A.p(s)}x=8
return A.d(B.aal(n),$async$SR)
case 8:m=a0
s=B.cbw(B.cel(m),e)
v=s
x=1
break
u=2
x=6
break
case 4:u=3
g=t.pop()
l=A.a9(g)
s=A.bB("Failed to expand event prompt: "+A.h(l))
throw A.p(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$SR,w)},
aal(d){return B.cuG(d)},
cuG(d){var x=0,w=A.l(y.y),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
var $async$aal=A.m(function(a0,a1){if(a0===1){t.push(a1)
x=u}for(;;)switch(x){case 0:g=0
f=null
m=y.g,l=y.b,k=y.y
case 3:if(!(g<130)){x=4
break}x=5
return A.d(A.ho(E.qE,null,l),$async$aal)
case 5:++g
u=7
x=10
return A.d(A.hk(A.bG(D.yh()+"/api/public/runpod/nlp/status/"+A.fc(2,d,C.bc,!1),0,null),null).cN(F.fm),$async$aal)
case 10:s=a1
if(s.b===429){j=A.bB("Too many requests \u2014 wait a moment and try again.")
throw A.p(j)}if(s.b===200){j=s
r=k.a(C.a4.bv(A.cI(A.cH(j.e)).bb(j.w),null))
q=D.aak(J.t(r,"status"))
if(q==="COMPLETED"){j=r
v=j
x=1
break}j=q
if(j==="FAILED"||j==="CANCELLED"){j=A.bB(D.aOe(r))
throw A.p(j)}}else D.c5N(s)
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
throw A.p(A.bB("NLP task timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$aal,w)},
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
ayt:function ayt(){},
ayu:function ayu(){},
ayv:function ayv(){},
ays:function ays(){},
ayq:function ayq(){},
ayr:function ayr(){}},G
J=c[1]
A=c[0]
C=c[2]
D=c[27]
E=c[171]
F=c[124]
B=a.updateHolder(c[17],B)
G=c[139]
B.a5_.prototype={
avw(){var x,w,v=this,u=A.I(y.w,y.b)
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
B.ayt.prototype={
$1(d){var x
y.d.a(d)
x=d==null?C.bv:d
x=J.cj(x,new B.ayu(),y.w).cH(0,new B.ayv())
x=A.v(x,x.$ti.i("r.E"))
return x},
$S:273}
B.ayu.prototype={
$1(d){return C.e.l(A.h(d))},
$S:13}
B.ayv.prototype={
$1(d){return d.length!==0},
$S:3}
B.ays.prototype={
$1(d){if(typeof d=="number")return d
return A.bE(A.h(d))},
$S:303}
B.ayq.prototype={
$1(d){if(typeof d=="number")return C.i.aI(d)
return A.ci(A.h(d),null)},
$S:725}
B.ayr.prototype={
$1(d){if(y.B.b(d))return A.aB(d,y.w,y.b)
return null},
$S:297};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.a5_,A.W)
w(A.d9,[B.ayt,B.ayu,B.ayv,B.ays,B.ayq,B.ayr])})()
var y={q:A.X("a5_"),g:A.X("cs"),y:A.X("S<e,@>"),B:A.X("S<@,@>"),w:A.X("e"),b:A.X("@"),d:A.X("a_<@>?")};(function constants(){G.Ie=new A.an(57531,"MaterialIcons",!1)})()};
(a=>{a["lMTTgEGvV0UU8UegJnhst9DfkDk="]=a.current})($__dart_deferred_initializers__);