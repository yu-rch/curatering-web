((a,b)=>{a[b]=a[b]||{}})(self,"$__dart_deferred_initializers__")
$__dart_deferred_initializers__.current=function(a,b,c,$){var J,A,C,D={aLS:function aLS(){}},B,E
J=c[1]
A=c[0]
C=c[2]
D=a.updateHolder(c[14],D)
B=c[33]
E=c[34]
D.aLS.prototype={
EM(d){return this.azK(d)},
azK(d){var x=0,w=A.l(y.i),v,u,t,s,r,q
var $async$EM=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:x=3
return A.d(A.et(A.bx("https://curatering.up.railway.app/api/online-inquiries",0,null),C.a6.cp(d,null),null,E.kL).cA(C.fp),$async$EM)
case 3:q=f
if(q.b<200||q.b>=300){u="Failed to submit online inquiry ("+q.b+")"
try{s=q
t=C.a6.bp(A.cj(A.ci(s.e)).b7(s.w),null)
if(y.l.b(t)&&t.h(0,"message")!=null)u=J.u(t.h(0,"message"))}catch(p){}throw A.p(A.li(u,q.b))}s=q
if(C.e.l(A.cj(A.ci(s.e)).b7(s.w)).length===0){v=C.hV
x=1
break}s=q
t=C.a6.bp(A.cj(A.ci(s.e)).b7(s.w),null)
v=y.l.b(t)?A.av(t,y.g,y.b):C.hV
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$EM,w)},
a5x(d,e,f){return this.blT(d,e,f)},
blT(d,e,f){var x=0,w=A.l(y.i),v
var $async$a5x=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/yolo-sam-infer",A.N(["imageBase64",d,"confidenceThreshold",0.25,"maxDetections",f,"maskFormat",e],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a5x,w)},
MB(d,e,f){return this.aF2(d,e,f)},
aF2(d,e,f){var x=0,w=A.l(y.i),v
var $async$MB=A.m(function(g,h){if(g===1)return A.i(h,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/swap-colors",A.N(["imageBase64",e,"masks",f,"edits",d],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$MB,w)},
WS(d,e,f,g,h,i,j,k){return this.ays(d,e,f,g,h,i,j,k)},
ays(d,e,f,g,h,i,j,k){var x=0,w=A.l(y.i),v
var $async$WS=A.m(function(l,m){if(l===1)return A.i(m,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/theme-search",A.N(["eventTitle",e,"eventType",f,"formalityLevel",g,"prompt",j,"baseImageUrl",d,"tags",k,"page",h,"perPage",i],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$WS,w)},
a4P(d){return this.bjE(d)},
bjE(d){var x=0,w=A.l(y.i),v
var $async$a4P=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/extract-objects",A.N(["imagesBase64",d,"confidenceThreshold",0.25,"maxDetections",20],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a4P,w)},
a30(d){return this.beF(d)},
beF(d){var x=0,w=A.l(y.i),v
var $async$a30=A.m(function(e,f){if(e===1)return A.i(f,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/analyze-base",A.N(["baseImageBase64",d],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a30,w)},
a3c(d,e){return this.bf1(d,e)},
bf1(d,e){var x=0,w=A.l(y.i),v
var $async$a3c=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/auto-place",A.N(["freeSpaces",d,"objects",e],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a3c,w)},
a7k(d,e){return this.bqO(d,e)},
bqO(d,e){var x=0,w=A.l(y.i),v
var $async$a7k=A.m(function(f,g){if(f===1)return A.i(g,w)
for(;;)switch(x){case 0:v=$.bG().dV("/api/public/events/theme-design/render-composite",A.N(["baseImageBase64",d,"objects",e],y.g,y.b)).cA(B.h6)
x=1
break
case 1:return A.j(v,w)}})
return A.k($async$a7k,w)}}
var z=a.updateTypes([]);(function inheritance(){var x=a.inherit
x(D.aLS,A.a8)})()
var y={i:A.ak("U<e,@>"),l:A.ak("U<@,@>"),g:A.ak("e"),b:A.ak("@")};(function constants(){B.h6=new A.bI(18e7)
B.Jm=new A.aj(C.J3,null,null,null,null)
B.zi=new A.aj(C.nU,null,null,null,null)
B.IJ=new A.al(58460,"MaterialIcons",!0)
B.Cd=new A.X(1/0,48)
B.CW=new A.M(!0,C.cS,null,null,null,null,20,C.a5,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.D_=new A.M(!0,null,null,null,null,null,12,C.ay,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null)
B.a38=new A.o("Back",null,null,null,null,null,null,null,null,null,null)})();(function lazyInitializers(){var x=a.lazyFinal
x($,"cKH","tl",()=>new D.aLS())})()};
(a=>{a["MiSHh5cpShBr8wIgbS+pAx5yWWI="]=a.current})($__dart_deferred_initializers__);