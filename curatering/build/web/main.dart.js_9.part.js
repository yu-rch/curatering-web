((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,B={
cdu(d,e){var x,w,v,u,t,s,r,q,p,o,n=new B.ayE(),m=new B.ayD(),l=new B.ayC(),k=d.h(0,"positive_prompt")
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
q=new B.ayB().$1(d.h(0,"steps"))
p=l.$1(d.h(0,"controlnet"))
o=d.h(0,"mode")
o=o==null?null:J.u(o)
return new B.a5_(x,k,w,v,u,t,s,n,r,m,q,p,o,l.$1(d.h(0,"transformation_plan")))},
aOF(d){var x=y.w,w=y.b
return y.B.b(d)?A.av(d,x,w):A.H(x,w)},
cgk(d){var x,w,v=B.aOF(d.h(0,"output")),u=B.aOF(v.h(0,"result"))
if(u.a!==0)return u
x=B.aOF(v.h(0,"analysis"))
if(x.a!==0)return x
if(v.a!==0)return v
w=B.aOF(d.h(0,"result"))
if(w.a!==0)return w
return d},
SC(d,e){return B.cwG(d,e)},
cwG(d,e){var x=0,w=A.l(y.q),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g
var $async$SC=A.m(function(f,a0){if(f===1){t.push(a0)
x=u}for(;;)switch(x){case 0:u=4
if(A.y_().length===0)A.aq(A.bz("API_BASE_URL is empty; set --dart-define=API_BASE_URL=... so the RunPod proxy can be reached."))
k=y.w
s=A.eA(d,k,y.b)
J.ax(s,"task_type","event_prompt_expansion")
r=s
s=A.bx(A.y_()+"/api/public/runpod/nlp/run",0,null)
j=A.N(["Content-Type","application/json"],k,k)
i=y.y
x=7
return A.d(A.et(s,C.a6.cp(A.N(["input",r],k,i),null),null,j).cA(C.qG),$async$SC)
case 7:q=a0
if(q.b!==200)A.c7J(q)
s=q
p=i.a(C.a6.bp(A.cj(A.ci(s.e)).b7(s.w),null))
o=A.aam(J.t(p,"status"))
n=A.cgj(p)
if(o==="COMPLETED"||J.t(p,"output")!=null){s=B.cdu(B.cgk(p),e)
v=s
x=1
break}s=o
if(s==="FAILED"||s==="CANCELLED"){s=A.bz(A.aOE(p))
throw A.p(s)}if(n==null||n.length===0){s=A.bz("NLP prompt expansion did not return a job id.")
throw A.p(s)}x=8
return A.d(B.aan(n),$async$SC)
case 8:m=a0
s=B.cdu(B.cgk(m),e)
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
return A.k($async$SC,w)},
aan(d){return B.cwE(d)},
cwE(d){var x=0,w=A.l(y.y),v,u=2,t=[],s,r,q,p,o,n,m,l,k,j,i,h,g,f,e
var $async$aan=A.m(function(a0,a1){if(a0===1){t.push(a1)
x=u}for(;;)switch(x){case 0:g=0
f=null
m=y.g,l=y.b,k=y.y
case 3:if(!(g<130)){x=4
break}x=5
return A.d(A.h2(C.qH,null,l),$async$aan)
case 5:++g
u=7
x=10
return A.d(A.fI(A.bx(A.y_()+"/api/public/runpod/nlp/status/"+A.eR(2,d,C.be,!1),0,null),null).cA(C.fo),$async$aan)
case 10:s=a1
if(s.b===429){j=A.bz("Too many requests \u2014 wait a moment and try again.")
throw A.p(j)}if(s.b===200){j=s
r=k.a(C.a6.bp(A.cj(A.ci(j.e)).b7(j.w),null))
q=A.aam(J.t(r,"status"))
if(q==="COMPLETED"){j=r
v=j
x=1
break}j=q
if(j==="FAILED"||j==="CANCELLED"){j=A.bz(A.aOE(r))
throw A.p(j)}}else A.c7J(s)
u=2
x=9
break
case 7:u=6
e=t.pop()
j=A.a4(e)
if(m.b(j)){p=j
o=J.u(p)
if(J.jm(o,"Job failed")||J.jm(o,"AI generation exceeded")||J.jm(o,"Worker returned"))throw e
f=p
A.a1z("NLP polling error (attempt "+A.h(g)+"): "+A.h(p))}else{n=j
f=n
j=A.h(g)
h=A.h(n)
A.a1z("NLP polling error (attempt "+j+"): "+h)}x=9
break
case 6:x=2
break
case 9:x=3
break
case 4:if(m.b(f))throw A.p(f)
throw A.p(A.bz("NLP task timed out after 650s waiting for the AI worker. Try again in a moment."))
case 1:return A.j(v,w)
case 2:return A.i(t.at(-1),w)}})
return A.k($async$aan,w)},
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
ayE:function ayE(){},
ayF:function ayF(){},
ayG:function ayG(){},
ayD:function ayD(){},
ayB:function ayB(){},
ayC:function ayC(){}},D
J=c[1]
A=c[0]
C=c[2]
B=a.updateHolder(c[16],B)
D=c[41]
B.a5_.prototype={
awb(){var x,w,v=this,u=A.H(y.w,y.b)
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
B.ayE.prototype={
$1(d){var x
y.d.a(d)
x=d==null?C.br:d
x=J.c_(x,new B.ayF(),y.w).ca(0,new B.ayG())
x=A.v(x,x.$ti.i("q.E"))
return x},
$S:452}
B.ayF.prototype={
$1(d){return C.e.l(A.h(d))},
$S:11}
B.ayG.prototype={
$1(d){return d.length!==0},
$S:4}
B.ayD.prototype={
$1(d){if(typeof d=="number")return d
return A.bA(A.h(d))},
$S:381}
B.ayB.prototype={
$1(d){if(typeof d=="number")return C.i.aJ(d)
return A.cf(A.h(d),null)},
$S:1178}
B.ayC.prototype={
$1(d){if(y.B.b(d))return A.av(d,y.w,y.b)
return null},
$S:304};(function inheritance(){var x=a.inherit,w=a.inheritMany
x(B.a5_,A.a8)
w(A.ht,[B.ayE,B.ayF,B.ayG,B.ayD,B.ayB,B.ayC])})()
var y={q:A.ak("a5_"),g:A.ak("cw"),y:A.ak("U<e,@>"),B:A.ak("U<@,@>"),w:A.ak("e"),b:A.ak("@"),d:A.ak("Y<@>?")};(function constants(){D.Is=new A.al(57531,"MaterialIcons",!1)})()};
(a=>{a["4Pg8qCUTv4uzGpkMCHvCKrC5AKQ="]=a.current})($__dart_deferred_initializers__);