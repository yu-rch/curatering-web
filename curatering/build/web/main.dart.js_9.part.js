((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={
ccz(d,e){var x,w,v,u,t,s,r,q,p,o,n=new B.ayu(),m=new B.ayt(),l=new B.ays(),k=d.h(0,"positive_prompt")
if(k==null)k=d.h(0,"prompt")
x=C.e.l(A.h(k==null?e:k))
if(x.length===0)throw A.p(A.bz("NLP prompt expansion returned no positive prompt."))
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
q=new B.ayr().$1(d.h(0,"steps"))
p=l.$1(d.h(0,"controlnet"))
o=d.h(0,"mode")
o=o==null?null:J.u(o)
return new B.a4X(x,k,w,v,u,t,s,n,r,m,q,p,o,l.$1(d.h(0,"transformation_plan")))},
aOv(d){var x=y.w,w=y.b
return y.B.b(d)?A.ax(d,x,w):A.H(x,w)},
cfp(d){var x,w,v=B.aOv(d.h(0,"output")),u=B.aOv(v.h(0,"result"))
if(u.a!==0)return u
x=B.aOv(v.h(0,"analysis"))
if(x.a!==0)return x
if(v.a!==0)return v
w=B.aOv(d.h(0,"result"))
if(w.a!==0)return w
return d},
SA(d,e){return B.cvL(d,e)},
cvL(d,e){var x=0,w=A.l(y.q),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g
var $async$SA=A.m(function(f,a0){if(f===1){t.push(a0)
x=u}for(;;)switch(x){case 0:u=4
if(A.xX().length===0)A.ap(A.bz("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
k=y.w
s=A.eA(d,k,y.b)
J.au(s,"task_type","event_prompt_expansion")
r=s
s=A.bx(A.xX()+"/api/public/runpod/nlp/run",0,null)
j=A.N(["Content-Type","application/json"],k,k)
i=y.y
x=7
return A.d(A.et(s,C.a6.cn(A.N(["input",r],k,i),null),null,j).cz(C.qy),$async$SA)
case 7:q=a0
if(q.b!==200)A.c6P(q)
s=q
p=i.a(C.a6.bq(A.ci(A.ch(s.e)).b6(s.w),null))
o=A.aak(J.t(p,"status"))
n=A.cfo(p)
if(o==="COMPLETED"||J.t(p,"output")!=null){s=B.ccz(B.cfp(p),e)
v=s
x=1
break}s=o
if(s==="FAILED"||s==="CANCELLED"){s=A.bz(A.aOu(p))
throw A.p(s)}if(n==null||n.length===0){s=A.bz("NLP prompt expansion did not return a job id.")
throw A.p(s)}x=8
return A.d(B.aal(n),$async$SA)
case 8:m=a0
s=B.ccz(B.cfp(m),e)
v=s
x=1
break
u=2
x=6
break
case 4:u=3
g=t.pop()
l=A.a4(g)
s=A.bz("Failed to expand event prompt: "+A.h(l))
throw A.p(s)
x=6
break
case 3:x=2
break
case 6:case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$SA,w)},
aal(d){return B.cvJ(d)},
cvJ(d){var x=0,w=A.l(y.y),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
var $async$aal=A.m(function(a0,a1){if(a0===1){t.push(a1)
x=u}for(;;)switch(x){case 0:g=0
f=null
m=y.g,l=y.b,k=y.y
case 3:if(!(g<130)){x=4
break}x=5
return A.d(A.h1(C.qz,null,l),$async$aal)
case 5:++g
u=7
x=10
return A.d(A.fF(A.bx(A.xX()+"/api/public/runpod/nlp/status/"+A.eR(2,d,C.bc,!1),0,null),null).cz(C.fm),$async$aal)
case 10:s=a1
if(s.b===429){j=A.bz("Too many requests \u2014 wait a moment and try again.")
throw A.p(j)}if(s.b===200){j=s
r=k.a(C.a6.bq(A.ci(A.ch(j.e)).b6(j.w),null))
q=A.aak(J.t(r,"status"))
if(q==="COMPLETED"){j=r
v=j
x=1
break}j=q
if(j==="FAILED"||j==="CANCELLED"){j=A.bz(A.aOu(r))
throw A.p(j)}}else A.c6P(s)
u=2
x=9
break
case 7:u=6
e=t.pop()
j=A.a4(e)
if(m.b(j)){p=j
o=J.u(p)
if(J.ji(o,"Job failed")||J.ji(o,"AI generation exceeded")||J.ji(o,"Worker returned"))throw e
f=p
A.a1x("NLP polling error (attempt "+A.h(g)+"): "+A.h(p))}else{n=j
f=n
j=A.h(g)
h=A.h(n)
A.a1x("NLP polling error (attempt "+j+"): "+h)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(m.b(f))throw A.p(f)
throw A.p(A.bz("NLP task timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$aal,w)},
a4X:function a4X(d,e,f,g,h,i,j,k,l,m,n,o,p,q){var _=this
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
ays:function ays(){}},D
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[16],B)
D=c[39]
B.a4X.prototype={
avW(){var x,w,v=this,u=A.H(y.w,y.b)
u.j(0,"positive_prompt",v.a)
x=v.b
if(x.length!==0)u.j(0,"negative_prompt",x)
u.j(0,"theme_tokens",v.c)
u.j(0,"lighting_tokens",v.d)
u.j(0,"style_tokens",v.e)
u.j(0,"decor_tokens",v.f)
u.j(0,"decor_elements",v.r)
u.j(0,"visual_keywords",v.w)
x=v.x
w=x!=null
if(w)u.j(0,"recommended_strength",x)
if(w)u.j(0,"strength",x)
x=v.y
if(x!=null)u.j(0,"cfg_scale",x)
x=v.z
if(x!=null)u.j(0,"steps",x)
x=v.Q
if(x!=null)u.j(0,"controlnet",x)
x=v.as
if(x!=null&&x.length!==0)u.j(0,"mode",x)
x=v.at
if(x!=null)u.j(0,"transformation_plan",x)
u.j(0,"nlp_expansion",v.bn())
return u},
bn(){var x,w,v=this,u=A.H(y.w,y.b)
u.j(0,"positive_prompt",v.a)
u.j(0,"negative_prompt",v.b)
u.j(0,"theme_tokens",v.c)
u.j(0,"lighting_tokens",v.d)
u.j(0,"style_tokens",v.e)
u.j(0,"decor_tokens",v.f)
u.j(0,"decor_elements",v.r)
u.j(0,"visual_keywords",v.w)
x=v.x
w=x!=null
if(w)u.j(0,"recommended_strength",x)
if(w)u.j(0,"strength",x)
x=v.y
if(x!=null)u.j(0,"cfg_scale",x)
x=v.z
if(x!=null)u.j(0,"steps",x)
x=v.Q
if(x!=null)u.j(0,"controlnet",x)
x=v.as
if(x!=null&&x.length!==0)u.j(0,"mode",x)
x=v.at
if(x!=null)u.j(0,"transformation_plan",x)
return u}}
var z=a.updateTypes([])
B.ayu.prototype={
$1(d){var x
y.d.a(d)
x=d==null?C.bA:d
x=J.c5(x,new B.ayv(),y.w).cq(0,new B.ayw())
x=A.v(x,x.$ti.i("r.E"))
return x},
$S:409}
B.ayv.prototype={
$1(d){return C.e.l(A.h(d))},
$S:14}
B.ayw.prototype={
$1(d){return d.length!==0},
$S:4}
B.ayt.prototype={
$1(d){if(typeof d=="number")return d
return A.bA(A.h(d))},
$S:397}
B.ayr.prototype={
$1(d){if(typeof d=="number")return C.i.aJ(d)
return A.ce(A.h(d),null)},
$S:1173}
B.ays.prototype={
$1(d){if(y.B.b(d))return A.ax(d,y.w,y.b)
return null},
$S:420};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.a4X,A.a8)
w(A.ht,[B.ayu,B.ayv,B.ayw,B.ayt,B.ayr,B.ays])})()
var y={q:A.aj("a4X"),g:A.aj("cw"),y:A.aj("U<e,@>"),B:A.aj("U<@,@>"),w:A.aj("e"),b:A.aj("@"),d:A.aj("Y<@>?")};(function constants(){D.Id=new A.al(57531,"MaterialIcons",!1)})()};
(a=>{a["THGrQtAa2A81iOH+w96hmtRHAtw="]=a.current})($__dart_deferred_initializers__);