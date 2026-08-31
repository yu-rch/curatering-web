((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D,E,F,B={
can(d,e){var x,w,v,u,t,s,r,q,p,o,n=new B.ayu(),m=new B.ayt(),l=new B.ays(),k=d.h(0,"positive_prompt")
if(k==null)k=d.h(0,"prompt")
x=C.e.n(A.h(k==null?e:k))
if(x.length===0)throw A.p(A.bz("NLP prompt expansion returned no positive prompt."))
k=d.h(0,"negative_prompt")
k=C.e.n(A.h(k==null?"":k))
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
q=new B.ayr().$1(d.h(0,"steps"))
p=l.$1(d.h(0,"controlnet"))
o=d.h(0,"mode")
o=o==null?null:J.A(o)
return new B.a50(x,k,w,v,u,t,s,n,r,m,q,p,o,l.$1(d.h(0,"transformation_plan")))},
aO4(d){var x=y.w,w=y.b
return y.B.b(d)?A.aI(d,x,w):A.H(x,w)},
cdg(d){var x,w,v=B.aO4(d.h(0,"output")),u=B.aO4(v.h(0,"result"))
if(u.a!==0)return u
x=B.aO4(v.h(0,"analysis"))
if(x.a!==0)return x
if(v.a!==0)return v
w=B.aO4(d.h(0,"result"))
if(w.a!==0)return w
return d},
SS(d,e){return B.ctg(d,e)},
ctg(d,e){var x=0,w=A.m(y.q),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g
var $async$SS=A.n(function(f,a0){if(f===1){t.push(a0)
x=u}for(;;)switch(x){case 0:u=4
if(D.yd().length===0)A.an(A.bz("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
k=y.w
s=A.fs(d,k,y.b)
J.aG(s,"task_type","event_prompt_expansion")
r=s
s=A.bE(D.yd()+"/api/public/runpod/nlp/run",0,null)
j=A.Q(["Content-Type","application/json"],k,k)
i=y.y
x=7
return A.d(A.eH(s,C.a4.cs(A.Q(["input",r],k,i),null),null,j).cK(C.xR),$async$SS)
case 7:q=a0
if(q.b!==200)D.c4z(q)
s=q
p=i.a(C.a4.bt(A.cA(A.cz(s.e)).b7(s.w),null))
o=D.aaj(J.t(p,"status"))
n=D.cdf(p)
if(o==="COMPLETED"||J.t(p,"output")!=null){s=B.can(B.cdg(p),e)
v=s
x=1
break}s=o
if(s==="FAILED"||s==="CANCELLED"){s=A.bz(D.aO3(p))
throw A.p(s)}if(n==null||n.length===0){s=A.bz("NLP prompt expansion did not return a job id.")
throw A.p(s)}x=8
return A.d(B.aak(n),$async$SS)
case 8:m=a0
s=B.can(B.cdg(m),e)
v=s
x=1
break
u=2
x=6
break
case 4:u=3
g=t.pop()
l=A.a9(g)
s=A.bz("Failed to expand event prompt: "+A.h(l))
throw A.p(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$SS,w)},
aak(d){return B.cte(d)},
cte(d){var x=0,w=A.m(y.y),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
var $async$aak=A.n(function(a0,a1){if(a0===1){t.push(a1)
x=u}for(;;)switch(x){case 0:g=0
f=null
m=y.g,l=y.b,k=y.y
case 3:if(!(g<130)){x=4
break}x=5
return A.d(A.iw(E.qI,null,l),$async$aak)
case 5:++g
u=7
x=10
return A.d(A.hd(A.bE(D.yd()+"/api/public/runpod/nlp/status/"+A.f8(2,d,C.b9,!1),0,null),null).cK(F.fg),$async$aak)
case 10:s=a1
if(s.b===429){j=A.bz("Too many requests \u2014 wait a moment and try again.")
throw A.p(j)}if(s.b===200){j=s
r=k.a(C.a4.bt(A.cA(A.cz(j.e)).b7(j.w),null))
q=D.aaj(J.t(r,"status"))
if(q==="COMPLETED"){j=r
v=j
x=1
break}j=q
if(j==="FAILED"||j==="CANCELLED"){j=A.bz(D.aO3(r))
throw A.p(j)}}else D.c4z(s)
u=2
x=9
break
case 7:u=6
e=t.pop()
j=A.a9(e)
if(m.b(j)){p=j
o=J.A(p)
if(J.jx(o,"Job failed")||J.jx(o,"AI generation exceeded")||J.jx(o,"Worker returned"))throw e
f=p
A.a1J("NLP polling error (attempt "+A.h(g)+"): "+A.h(p))}else{n=j
f=n
j=A.h(g)
h=A.h(n)
A.a1J("NLP polling error (attempt "+j+"): "+h)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(m.b(f))throw A.p(f)
throw A.p(A.bz("NLP task timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.k(v,w)
case 2:return A.j(t.at(-1),w)}})
return A.l($async$aak,w)},
a50:function a50(d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
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
ayu:function ayu(){},
ayv:function ayv(){},
ayw:function ayw(){},
ayt:function ayt(){},
ayr:function ayr(){},
ays:function ays(){}},G
J=c[1]
A=c[0]
C=c[2]
D=c[19]
E=c[54]
F=c[55]
B=a.updateHolder(c[14],B)
G=c[60]
B.a50.prototype={
auR(){var x,w,v=this,u=A.H(y.w,y.b)
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
bm(){var x,w,v=this,u=A.H(y.w,y.b)
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
B.ayu.prototype={
$1(d){var x
y.d.a(d)
x=d==null?C.by:d
x=J.cq(x,new B.ayv(),y.w).d4(0,new B.ayw())
x=A.v(x,x.$ti.i("r.E"))
return x},
$S:211}
B.ayv.prototype={
$1(d){return C.e.n(A.h(d))},
$S:13}
B.ayw.prototype={
$1(d){return d.length!==0},
$S:4}
B.ayt.prototype={
$1(d){if(typeof d=="number")return d
return A.bB(A.h(d))},
$S:206}
B.ayr.prototype={
$1(d){if(typeof d=="number")return C.i.aI(d)
return A.cx(A.h(d),null)},
$S:725}
B.ays.prototype={
$1(d){if(y.B.b(d))return A.aI(d,y.w,y.b)
return null},
$S:245};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.a50,A.X)
w(A.eB,[B.ayu,B.ayv,B.ayw,B.ayt,B.ayr,B.ays])})()
var y={q:A.ac("a50"),g:A.ac("cm"),y:A.ac("R<e,@>"),B:A.ac("R<@,@>"),w:A.ac("e"),b:A.ac("@"),d:A.ac("Y<@>?")};(function constants(){G.Ix=new A.al(57531,"MaterialIcons",!1)})()};
(a=>{a["3DE8kDP1+3yENV7fh9rG9mf5IJs="]=a.current})($__dart_deferred_initializers__);